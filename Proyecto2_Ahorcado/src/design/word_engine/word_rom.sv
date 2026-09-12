`timescale 1ns/1ps
// ROM constante de 50 palabras; word_bank.txt es la referencia del testbench.
// Character 0 is word_data[7:0]; unused bytes are ASCII spaces.
// Constant case ROM: Vivado may implement it using LUTs.
module word_rom (
    input  logic [5:0]  index,
    output logic [95:0] word_data,
    output logic [3:0]  word_length,
    output logic        valid
);
    always_comb begin
        word_data = {12{8'h20}};
        word_length = 4'd0;
        valid = 1'b1;
        case (index)
            6'd0: begin word_data = 96'h202020202020202041534143; word_length = 4'd4; end // CASA
            6'd1: begin word_data = 96'h20202020202020204153454D; word_length = 4'd4; end // MESA
            6'd2: begin word_data = 96'h2020202020202020414E554C; word_length = 4'd4; end // LUNA
            6'd3: begin word_data = 96'h2020202020202052414C4F53; word_length = 4'd5; end // SOLAR
            6'd4: begin word_data = 96'h202020202020204C4F425241; word_length = 4'd5; end // ARBOL
            6'd5: begin word_data = 96'h202020202020204F5242494C; word_length = 4'd5; end // LIBRO
            6'd6: begin word_data = 96'h202020202020204F52524550; word_length = 4'd5; end // PERRO
            6'd7: begin word_data = 96'h20202020202020204F544147; word_length = 4'd4; end // GATO
            6'd8: begin word_data = 96'h2020202020202020524F4C46; word_length = 4'd4; end // FLOR
            6'd9: begin word_data = 96'h202020202020202041554741; word_length = 4'd4; end // AGUA
            6'd10: begin word_data = 96'h20202020202020204542554E; word_length = 4'd4; end // NUBE
            6'd11: begin word_data = 96'h202020202020204F504D4143; word_length = 4'd5; end // CAMPO
            6'd12: begin word_data = 96'h202020202020204159414C50; word_length = 4'd5; end // PLAYA
            6'd13: begin word_data = 96'h202020202020204A4F4C4552; word_length = 4'd5; end // RELOJ
            6'd14: begin word_data = 96'h202020202020204C45504150; word_length = 4'd5; end // PAPEL
            6'd15: begin word_data = 96'h2020202020204F4E494D4143; word_length = 4'd6; end // CAMINO
            6'd16: begin word_data = 96'h2020202020414E41544E4556; word_length = 4'd7; end // VENTANA
            6'd17: begin word_data = 96'h20202020204F44414C434554; word_length = 4'd7; end // TECLADO
            6'd18: begin word_data = 96'h20202020414C4C41544E4150; word_length = 4'd8; end // PANTALLA
            6'd19: begin word_data = 96'h202020204F54495543524943; word_length = 4'd8; end // CIRCUITO
            6'd20: begin word_data = 96'h2020202020414D4554534953; word_length = 4'd7; end // SISTEMA
            6'd21: begin word_data = 96'h20202020204C415449474944; word_length = 4'd7; end // DIGITAL
            6'd22: begin word_data = 96'h20202020204149524F4D454D; word_length = 4'd7; end // MEMORIA
            6'd23: begin word_data = 96'h202020204F52545349474552; word_length = 4'd8; end // REGISTRO
            6'd24: begin word_data = 96'h20202020524F4441544E4F43; word_length = 4'd8; end // CONTADOR
            6'd25: begin word_data = 96'h2020202020415242414C4150; word_length = 4'd7; end // PALABRA
            6'd26: begin word_data = 96'h202020204F444143524F4841; word_length = 4'd8; end // AHORCADO
            6'd27: begin word_data = 96'h202020202053454E4F544F42; word_length = 4'd7; end // BOTONES
            6'd28: begin word_data = 96'h2020202020204F44494E4F53; word_length = 4'd6; end // SONIDO
            6'd29: begin word_data = 96'h2020202020204F504D454954; word_length = 4'd6; end // TIEMPO
            6'd30: begin word_data = 96'h20202020204F544E45544E49; word_length = 4'd7; end // INTENTO
            6'd31: begin word_data = 96'h202020204149524F54434956; word_length = 4'd8; end // VICTORIA
            6'd32: begin word_data = 96'h2041524F44415455504D4F43; word_length = 4'd11; end // COMPUTADORA
            6'd33: begin word_data = 96'h204143494E4F525443454C45; word_length = 4'd11; end // ELECTRONICA
            6'd34: begin word_data = 96'h204441444953524556494E55; word_length = 4'd11; end // UNIVERSIDAD
            6'd35: begin word_data = 96'h204F49524F5441524F42414C; word_length = 4'd11; end // LABORATORIO
            6'd36: begin word_data = 96'h4E4F4943414D4152474F5250; word_length = 4'd12; end // PROGRAMACION
            6'd37: begin word_data = 96'h415255544345544955515241; word_length = 4'd12; end // ARQUITECTURA
            6'd38: begin word_data = 96'h4E4F49434143494E554D4F43; word_length = 4'd12; end // COMUNICACION
            6'd39: begin word_data = 96'h2020524F44415345434F5250; word_length = 4'd10; end // PROCESADOR
            6'd40: begin word_data = 96'h2020524F545349534E415254; word_length = 4'd10; end // TRANSISTOR
            6'd41: begin word_data = 96'h204149434E45545349534552; word_length = 4'd11; end // RESISTENCIA
            6'd42: begin word_data = 96'h202020524F54494341504143; word_length = 4'd9; end // CAPACITOR
            6'd43: begin word_data = 96'h20204149434E455543455246; word_length = 4'd10; end // FRECUENCIA
            6'd44: begin word_data = 96'h2020204F4C4F434F544F5250; word_length = 4'd9; end // PROTOCOLO
            6'd45: begin word_data = 96'h2020204F49524F5441454C41; word_length = 4'd9; end // ALEATORIO
            6'd46: begin word_data = 96'h2020204149434E4555434553; word_length = 4'd9; end // SECUENCIA
            6'd47: begin word_data = 96'h4F44415A494E4F52434E4953; word_length = 4'd12; end // SINCRONIZADO
            6'd48: begin word_data = 96'h204E4F4953494D534E415254; word_length = 4'd11; end // TRANSMISION
            6'd49: begin word_data = 96'h2020204E4F49435045434552; word_length = 4'd9; end // RECEPCION
            default: valid = 1'b0;
        endcase
    end
endmodule
