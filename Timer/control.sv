module Control (
    input  logic clk,
    input  logic reset,
    input  logic start_bit,        // bit0 (R/W)
    input  logic autoreload_bit,   // bit1 (R/W)
    input  logic timeout_in,       // pulso desde el contador

    output logic enable_timer,     // corre el contador
    output logic load_en,          // pulso 1 ciclo, SINCRONIZADO
    output logic timeout_flag      // bit2 (R): latcheado hasta nuevo start
);
    // --- Detector de flanco de start, 100% síncrono ---
    logic start_q, start_qq;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            start_q  <= 1'b0;
            start_qq <= 1'b0;
        end else begin
            start_q  <= start_bit;   // muestreo actual
            start_qq <= start_q;     // muestreo previo
        end
    end
    wire start_rise = start_q & ~start_qq;  // flanco de subida estable (1 ciclo DESPUÉS de escribir start=1)

    // --- Estado de "en marcha" ---
    logic running;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            running      <= 1'b0;
            timeout_flag <= 1'b0;
        end else begin
            // flag de timeout: set con timeout, clear con nuevo start
            if (timeout_in)      timeout_flag <= 1'b1;
            else if (start_rise) timeout_flag <= 1'b0;

            // control de ejecución
            if (start_rise) begin
                running <= 1'b1;          // arranca
            end else if (timeout_in) begin
                running <= autoreload_bit; // si autoreload=1 sigue; si no, se detiene
            end
        end
    end

    // --- Generación de load_en REGISTRADO (1 ciclo completo) ---
    // Se dispara al ciclo SIGUIENTE al flanco de start, y en cada timeout si autoreload=1
    always_ff @(posedge clk or posedge reset) begin
        if (reset) load_en <= 1'b0;
        else       load_en <= start_rise | (timeout_in & autoreload_bit);
    end

    assign enable_timer = running;
endmodule
