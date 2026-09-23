// Codificaciones internas compartidas; no forman parte del bus del sistema.
package cpu_pkg;
    localparam logic [3:0] ALU_ADD=0, ALU_SUB=1, ALU_AND=2, ALU_OR=3,
        ALU_XOR=4, ALU_SLL=5, ALU_SRL=6, ALU_SRA=7, ALU_SLT=8, ALU_SLTU=9;
    localparam logic [2:0] IMM_I=0, IMM_S=1, IMM_B=2, IMM_U=3, IMM_J=4;
    localparam logic [2:0] K_ALU=0, K_LOAD=1, K_STORE=2, K_BRANCH=3,
        K_JAL=4, K_JALR=5;
    typedef enum logic [3:0] {FETCH_REQ, FETCH_CAPTURE, DECODE, EXECUTE,
        LOAD_REQ, LOAD_CAPTURE, STORE, WRITEBACK, COMMIT, FAULT} state_t;
endpackage
