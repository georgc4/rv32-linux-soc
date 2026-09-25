`timescale 1ns/1ps
// One-request Sv32 translator and physical-bus arbiter with a direct-mapped TLB.
// SFENCE.VMA invalidates all entries. PTE A/D bits are set by a bus write.
// The one-hart SoC has no other bus master; external memory must not mutate
// page tables concurrently with this read/modify/write sequence.
module sv32_bus_adapter #(
    parameter integer TLB_ENTRIES = 8
) (
    input wire clk, rst_n,
    input wire [1:0] privilege,
    input wire [31:0] satp, mstatus,
    input wire tlb_flush,
    input wire i_req_valid,
    output wire i_req_ready,
    input wire [31:0] i_req_addr,
    output wire i_resp_valid,
    input wire i_resp_ready,
    output wire [31:0] i_resp_data,
    output wire i_resp_err,
    output wire i_resp_page_fault,
    input wire d_req_valid,
    output wire d_req_ready,
    input wire [31:0] d_req_addr,
    input wire d_req_write,
    input wire [31:0] d_req_wdata,
    input wire [3:0] d_req_wstrb,
    output wire d_resp_valid,
    input wire d_resp_ready,
    output wire [31:0] d_resp_data,
    output wire d_resp_err,
    output wire d_resp_page_fault,
    output wire bus_req_valid,
    input wire bus_req_ready,
    output wire [31:0] bus_req_addr,
    output wire bus_req_write,
    output wire [31:0] bus_req_wdata,
    output wire [3:0] bus_req_wstrb,
    input wire bus_resp_valid,
    output wire bus_resp_ready,
    input wire [31:0] bus_resp_data,
    input wire bus_resp_err
);
    localparam [3:0] IDLE = 0, WALK_REQ = 1, WALK_RESP = 2,
                     UPDATE_REQ = 3, UPDATE_RESP = 4,
                     ACCESS_REQ = 5, ACCESS_RESP = 6, DONE = 7;
    reg [3:0] state;
    reg is_data, is_write;
    reg [31:0] virtual_addr, write_data, response_data;
    reg [3:0] write_strb;
    reg [1:0] effective_priv;
    reg sum_enable, mxr_enable, level1;
    reg [33:0] walk_addr, access_addr;
    reg [31:0] pte_updated;
    reg [30:0] root_context;
    localparam integer TLB_INDEX_BITS = $clog2(TLB_ENTRIES);
    reg [TLB_ENTRIES-1:0] tlb_valid;
    reg [19:0] tlb_vpn [0:TLB_ENTRIES-1];
    reg [30:0] tlb_context [0:TLB_ENTRIES-1];
    reg [31:0] tlb_pte [0:TLB_ENTRIES-1];
    reg tlb_level1 [0:TLB_ENTRIES-1];
    integer tlb_i;
    reg response_error, response_page_fault;
    wire [1:0] request_priv = d_req_valid && privilege == 2'd3 && mstatus[17] ?
                              mstatus[12:11] : privilege;
    wire do_translate = satp[31] && request_priv != 2'd3;
    wire [31:0] pte = bus_resp_data;
    wire pte_leaf = pte[1] || pte[3];
    wire pte_invalid = !pte[0] || (pte[2] && !pte[1]);
    wire permission_ok = is_data ?
        (is_write ? pte[2] : (pte[1] || (mxr_enable && pte[3]))) : pte[3];
    wire privilege_ok = effective_priv == 2'd0 ? pte[4] :
                        (is_data ? (!pte[4] || sum_enable) : !pte[4]);
    wire [21:0] page_ppn = level1 ? {pte[31:20], virtual_addr[21:12]} : pte[31:10];
    wire [33:0] leaf_addr = {page_ppn, virtual_addr[11:0]};
    wire [33:0] next_walk_addr = {pte[31:10], 12'b0} +
                                 {22'b0, virtual_addr[21:12], 2'b0};
    wire choose_data = d_req_valid;
    wire [31:0] request_vaddr = choose_data ? d_req_addr : i_req_addr;
    wire [TLB_INDEX_BITS-1:0] request_index = request_vaddr[12 +: TLB_INDEX_BITS];
    wire [TLB_INDEX_BITS-1:0] refill_index = virtual_addr[12 +: TLB_INDEX_BITS];
    wire [31:0] cached_pte = tlb_pte[request_index];
    wire unused_cached_pte_bits = &{1'b0, cached_pte[9:5], cached_pte[0]};
    wire tlb_hit = tlb_valid[request_index] &&
                   tlb_vpn[request_index] == request_vaddr[31:12] &&
                   tlb_context[request_index] == satp[30:0] &&
                   (!choose_data || !d_req_write || tlb_pte[request_index][7]);
    wire cached_permission_ok = choose_data ?
        (d_req_write ? cached_pte[2] :
         (cached_pte[1] || (mstatus[19] && cached_pte[3]))) : cached_pte[3];
    wire cached_privilege_ok = request_priv == 2'd0 ? cached_pte[4] :
        (choose_data ? (!cached_pte[4] || mstatus[18]) : !cached_pte[4]);
    wire [33:0] cached_addr = tlb_level1[request_index] ?
        {cached_pte[31:20], request_vaddr[21:0]} :
        {cached_pte[31:10], request_vaddr[11:0]};
    wire unused_fields = &{1'b0, pte[5], virtual_addr[31:22],
                           satp[30:22], mstatus[31:20],
                           mstatus[16:13], mstatus[10:0]};

    assign i_req_ready = state == IDLE && rst_n && !choose_data;
    assign d_req_ready = state == IDLE && rst_n;
    assign i_resp_valid = state == DONE && !is_data;
    assign d_resp_valid = state == DONE && is_data;
    assign i_resp_data = response_data;
    assign d_resp_data = response_data;
    assign i_resp_err = response_error;
    assign d_resp_err = response_error;
    assign i_resp_page_fault = response_page_fault;
    assign d_resp_page_fault = response_page_fault;
    assign bus_req_valid = (state == WALK_REQ && walk_addr[33:32] == 0) ||
                           state == UPDATE_REQ ||
                           (state == ACCESS_REQ && access_addr[33:32] == 0);
    assign bus_req_addr = state == ACCESS_REQ ? access_addr[31:0] : walk_addr[31:0];
    assign bus_req_write = state == UPDATE_REQ || (state == ACCESS_REQ && is_write);
    assign bus_req_wdata = state == UPDATE_REQ ? pte_updated : write_data;
    assign bus_req_wstrb = state == UPDATE_REQ ? 4'b1111 :
                           state == ACCESS_REQ ? write_strb : 4'b0;
    assign bus_resp_ready = state == WALK_RESP || state == UPDATE_RESP || state == ACCESS_RESP;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            is_data <= 0;
            is_write <= 0;
            virtual_addr <= 0;
            write_data <= 0;
            write_strb <= 0;
            effective_priv <= 2'd3;
            sum_enable <= 0;
            mxr_enable <= 0;
            level1 <= 0;
            walk_addr <= 0;
            access_addr <= 0;
            pte_updated <= 0;
            root_context <= 0;
            tlb_valid <= 0;
            for (tlb_i = 0; tlb_i < TLB_ENTRIES; tlb_i = tlb_i + 1) begin
                tlb_vpn[tlb_i] <= 0;
                tlb_context[tlb_i] <= 0;
                tlb_pte[tlb_i] <= 0;
                tlb_level1[tlb_i] <= 0;
            end
            response_data <= 0;
            response_error <= 0;
            response_page_fault <= 0;
        end else begin
            case (state)
            IDLE: if (i_req_valid || d_req_valid) begin
                is_data <= choose_data;
                is_write <= choose_data && d_req_write;
                virtual_addr <= choose_data ? d_req_addr : i_req_addr;
                write_data <= choose_data ? d_req_wdata : 32'b0;
                write_strb <= choose_data ? d_req_wstrb : 4'b0;
                effective_priv <= request_priv;
                root_context <= satp[30:0];
                sum_enable <= mstatus[18];
                mxr_enable <= mstatus[19];
                response_data <= 0;
                response_error <= 0;
                response_page_fault <= 0;
                if (do_translate) begin
                    if (tlb_hit) begin
                        if (!cached_permission_ok || !cached_privilege_ok) begin
                            response_error <= 1;
                            response_page_fault <= 1;
                            state <= DONE;
                        end else begin
                            access_addr <= cached_addr;
                            state <= ACCESS_REQ;
                        end
                    end else begin
                        level1 <= 1;
                        walk_addr <= {satp[21:0], 12'b0} +
                                     {22'b0, request_vaddr[31:22], 2'b0};
                        state <= WALK_REQ;
                    end
                end else begin
                    access_addr <= {2'b0, choose_data ? d_req_addr : i_req_addr};
                    state <= ACCESS_REQ;
                end
            end
            WALK_REQ: if (walk_addr[33:32] != 0) begin
                response_error <= 1;
                state <= DONE;
            end else if (bus_req_ready) state <= WALK_RESP;
            WALK_RESP: if (bus_resp_valid) begin
                if (bus_resp_err) begin
                    response_error <= 1;
                    state <= DONE;
                end else if (pte_invalid || (!pte_leaf &&
                             (!level1 || pte[7:6] != 0 || pte[4])) ||
                             (pte_leaf && (level1 && pte[19:10] != 0 ||
                                           !permission_ok || !privilege_ok))) begin
                    response_error <= 1;
                    response_page_fault <= 1;
                    state <= DONE;
                end else if (!pte_leaf) begin
                    walk_addr <= next_walk_addr;
                    level1 <= 0;
                    state <= WALK_REQ;
                end else if (leaf_addr[33:32] != 0) begin
                    response_error <= 1;
                    state <= DONE;
                end else begin
                    access_addr <= leaf_addr;
                    if (!pte[6] || (is_write && !pte[7])) begin
                        pte_updated <= pte | 32'h0000_0040 | (is_write ? 32'h0000_0080 : 32'b0);
                        state <= UPDATE_REQ;
                    end else begin
                        tlb_valid[refill_index] <= 1;
                        tlb_vpn[refill_index] <= virtual_addr[31:12];
                        tlb_context[refill_index] <= root_context;
                        tlb_pte[refill_index] <= pte;
                        tlb_level1[refill_index] <= level1;
                        state <= ACCESS_REQ;
                    end
                end
            end
            UPDATE_REQ: if (bus_req_ready) state <= UPDATE_RESP;
            UPDATE_RESP: if (bus_resp_valid) begin
                if (bus_resp_err) begin
                    response_error <= 1;
                    state <= DONE;
                end else begin
                    tlb_valid[refill_index] <= 1;
                    tlb_vpn[refill_index] <= virtual_addr[31:12];
                    tlb_context[refill_index] <= root_context;
                    tlb_pte[refill_index] <= pte_updated;
                    tlb_level1[refill_index] <= level1;
                    state <= ACCESS_REQ;
                end
            end
            ACCESS_REQ: if (access_addr[33:32] != 0) begin
                response_error <= 1;
                state <= DONE;
            end else if (bus_req_ready) state <= ACCESS_RESP;
            ACCESS_RESP: if (bus_resp_valid) begin
                response_data <= bus_resp_data;
                response_error <= bus_resp_err;
                state <= DONE;
            end
            DONE: if ((!is_data && i_resp_ready) || (is_data && d_resp_ready))
                state <= IDLE;
            default: state <= IDLE;
            endcase
            if (tlb_flush) tlb_valid <= 0;
        end
    end
endmodule
