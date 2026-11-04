
# Compila cada top de prueba con varias variantes y anchos, y guarda en resultados.csv:
#   modulo, variante, N, ALMs, registros, bloques DSP, slack de setup (ns), Fmax (MHz)
#
#   quartus_sh -t run_exp.tcl


load_package flow

#  Archivos 
set src ../src
set archivos [list \
    $src/alu_types_pkg.sv \
    $src/full_adder.sv \
    $src/ripple_adder.sv \
    $src/mux_2_1.sv \
    $src/mux_2_1_param.sv \
    $src/not_nbit.sv \
    $src/or_nbit.sv \
    $src/shift_left.sv \
    $src/shift_left_rotator.sv \
    $src/shift_right_rotator.sv \
    $src/product.sv \
    $src/alu_nbit.sv \
    $src/hex7seg.sv \
    ripple_carry_adder_bh.sv \
    hex7seg_decoder.sv \
    alu_nbit_bh.sv \
    top_exp_adder.sv \
    top_exp_alu.sv \
    top_exp_hex.sv]

#  Utilidades 
proc leer {archivo} {
    set f [open $archivo r]
    set texto [read $f]
    close $f
    return $texto
}

# Saca un numero de un texto con una expresion regular (sin comas). Si no lo encuentra, "NA".
proc sacar {patron texto} {
    if {[regexp $patron $texto -> valor]} {
        return [string map {, ""} $valor]
    }
    return "NA"
}

# Compila un top con un N y una variante. Devuelve 1 si todo salio bien.
proc compilar {top n behav puertos} {
    project_new exp -overwrite

    set_global_assignment -name FAMILY "Cyclone V"
    set_global_assignment -name DEVICE 5CSXFC6D6F31C6
    set_global_assignment -name TOP_LEVEL_ENTITY $top
    set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
    set_global_assignment -name SDC_FILE exp.sdc
    foreach f $::archivos {
        set_global_assignment -name SYSTEMVERILOG_FILE $f
    }

    # Las entradas y salidas no van a pines reales: asi no hacen falta cientos de pines
    # y el Timing Analyzer solo mide el camino registro -> modulo -> registro
    foreach p $puertos {
        set_instance_assignment -name VIRTUAL_PIN ON -to "${p}*"
    }

    if {$n ne "-"} {
        set_parameter -name N $n
    }
    set_parameter -name BEHAV $behav
    export_assignments

    set ok 1
    if {[catch {
        execute_module -tool map
        execute_module -tool fit
        execute_module -tool sta
    } msg]} {
        puts "ERROR compilando $top N=$n BEHAV=$behav: $msg"
        set ok 0
    }

    project_close
    return $ok
}

# Lee los reportes de la ultima compilacion
proc resultados {} {
    set fit [leer output_files/exp.fit.summary]
    set sta [leer output_files/exp.sta.summary]

    set alms [sacar {Logic utilization \(in ALMs\)\s*:\s*([\d,]+)} $fit]
    set regs [sacar {Total registers\s*:\s*([\d,]+)} $fit]
    set dsp  [sacar {Total DSP Blocks\s*:\s*([\d,]+)} $fit]

    # Peor caso: modelo Slow 1100mV 85C, analisis de setup del reloj clk
    set slack [sacar {Slow 1100mV 85C Model Setup 'clk'\s*\n\s*Slack\s*:\s*([-\d.]+)} $sta]

    # Fmax = 1 / (periodo - slack), con periodo = 20 ns
    if {$slack eq "NA"} {
        set fmax "NA"
    } else {
        set fmax [format "%.2f" [expr {1000.0 / (20.0 - $slack)}]]
    }

    return [list $alms $regs $dsp $slack $fmax]
}

#  Corrida 
set csv [open resultados.csv w]
puts $csv "modulo,variante,N,alms,registros,dsp,slack_ns,fmax_mhz"

proc correr {csv modulo top anchos puertos} {
    foreach n $anchos {
        foreach behav {0 1} {
            if {$behav == 0} { set variante estructural } else { set variante behavioral }
            puts "=== $modulo $variante N=$n ==="

            if {[compilar $top $n $behav $puertos]} {
                set r [resultados]
            } else {
                set r [list ERROR ERROR ERROR ERROR ERROR]
            }

            set linea "$modulo,$variante,$n,[join $r ,]"
            puts $csv $linea
            flush $csv
            puts $linea
        }
    }
}

correr $csv sumador     top_exp_adder {4 8 16 32 64} {a_in b_in cin_in s_out cout_out}
correr $csv alu         top_exp_alu   {4 8 16 32}    {a_in b_in op_in r_out flags_out}
correr $csv hex7seg     top_exp_hex   {-}            {x_in seg_out}

close $csv
puts "Listo: resultados en resultados.csv"
