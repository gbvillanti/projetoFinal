        PUBLIC  __iar_program_start
        PUBLIC  __vector_table

        SECTION .text:CODE:REORDER(2)
        
        ;; Keep vector table even if it's not referenced
        REQUIRE __vector_table
        
        THUMB
        
; System Control definitions
SYSCTL_BASE             EQU     0x400FE000
SYSCTL_RCGCGPIO         EQU     0x0608
SYSCTL_PRGPIO		EQU     0x0A08
SYSCTL_RCGCUART         EQU     0x0618
SYSCTL_PRUART           EQU     0x0A18
PORTA_BIT               EQU     000000000000001b ; bit  0 = Port A
UART0_BIT               EQU     00000001b        ; bit  0 = UART 0

; NVIC definitions
NVIC_BASE               EQU     0xE000E000
NVIC_EN1                EQU     0x0104
VIC_DIS1                EQU     0x0184
NVIC_PEND1              EQU     0x0204
NVIC_UNPEND1            EQU     0x0284
NVIC_ACTIVE1            EQU     0x0304
NVIC_PRI12              EQU     0x0430

; GPIO Port definitions
GPIO_PORTA_BASE         EQU     0x40058000
GPIO_DIR                EQU     0x0400
GPIO_IS                 EQU     0x0404
GPIO_IBE                EQU     0x0408
GPIO_IEV                EQU     0x040C
GPIO_IM                 EQU     0x0410
GPIO_RIS                EQU     0x0414
GPIO_MIS                EQU     0x0418
GPIO_ICR                EQU     0x041C
GPIO_AFSEL              EQU     0x0420
GPIO_PUR                EQU     0x0510
GPIO_DEN                EQU     0x051C
GPIO_PCTL               EQU     0x052C

; UART Definitions
UART_PORT0_BASE         EQU     0x4000C000
UART_FR                 EQU     0x0018
UART_IBRD               EQU     0x0024
UART_FBRD               EQU     0x0028
UART_LCRH               EQU     0x002C
UART_CTL                EQU     0x0030
UART_CC                 EQU     0x0FC8

;UART bit definitions
TXFE_BIT                EQU     10000000b ; TX FIFO full
RXFF_BIT                EQU     01000000b ; RX FIFO empty
BUSY_BIT                EQU     00001000b ; Busy


; Main program

__iar_program_start
        
main:   MOV R2, #(UART0_BIT)
	BL UART_enable ; habilita clock ao port 0 de UART

        MOV R2, #(PORTA_BIT)
	BL GPIO_enable ; habilita clock ao port A de GPIO
        
	LDR R0, =GPIO_PORTA_BASE
        MOV R1, #00000011b ; bits 0 e 1 como especiais
        BL GPIO_special

	MOV R1, #0xFF ; máscara das funções especiais no port A (bits 1 e 0)
        MOV R2, #0x11  ; funções especiais RX e TX no port A (UART)
        BL GPIO_select

	LDR R0, =UART_PORT0_BASE
        BL UART_config ; configura periférico UART0
        
        BL Instrucao ; mostra msg de instrução
        BL Insira ; mostra msg para inserir a operação
        MOV R10, #0 ; para verificar op

        
loop:   MOV R3, #0
        MOV R9, #10
        MOV R7, #0
        MOV R12, #12 ; indica se numero resultante é negativo 
        MOV R11, #0  ; trata tamanho dos numeros

wrx:    LDR R2, [R0, #UART_FR] ; status da UART
        TST R2, #RXFF_BIT ; receptor cheio?
        BEQ wrx
        LDR R1, [R0] ; lê registrador de dados da UART0

        B ValidaCaracter      

wtx:    LDR R2, [R0, #UART_FR] ; status da UART
        TST R2, #TXFE_BIT ; transmissor vazio?
        BEQ wtx
        STR R1, [R0] ; escreve no registrador de dados da UART0 (transmite)

        
        CMP R1, #'+'
        BEQ ExecSoma
        CMP R1, #'-'
        BEQ ExecSub
        CMP R1, #'*'
        BEQ ExecMul
        CMP R1, #'/'
        BEQ ExecDiv
        CMP R1, #'='
        BEQ ExecConta
        
        MOV R2, R1
        SUBS R2, #48 ; converte ASCII
        MUL  R3, R9  ; multiplica x10
        ADD R3, R2   ; soma com o valor multiplicado para construir o numero
        ADD R11, #1  ; incrementa tamanho do numero

        B wrx

;=====Implementação das SUB-ROTINAS======;
ExecSoma
      MOV R4, R3
      MOV R10, #1
      B loop
      ;;endExecSoma
      
ExecSub
      MOV R4, R3
      MOV R10, #2
      B loop
      ;;endExecSub

ExecMul
      MOV R4, R3
      MOV R10, #3
      B loop
      ;;endExecMul

ExecDiv
      MOV R4, R3
      MOV R10, #4
      B loop
      ;;endExecDiv

ExecConta
      CMP R10, #0
      IT EQ
        BLEQ SemConta

      CMP R10, #1
      IT EQ
        BLEQ Soma
      
      CMP R10, #2
      IT EQ
        BLEQ Subtrai
        
      CMP R10, #3
      IT EQ
        BLEQ Multiplica 
        
      CMP R10, #4
      IT EQ
        BLEQ Divide
        
      MOV R8, R1  
      BL TrataInfo
      BL SerialPrint
      MOV R10, #0
      BL QuebraDeLinha
      BL Insira
      
      B loop
      ;;endExecConta
     
TrataInfo:
      PUSH {LR}
      BL TrataNegativo
      POP {LR}
      PUSH {R1}
      ADD R7, #1
      SDIV R1, R9
      CBZ R1, retornaSR
      B TrataInfo
retornaSR
      BX LR
      ;;endTrataInfo
   
TrataNegativo
      AND R5, R1, #10000000000000000000000000000000b
      CMP R5, #10000000000000000000000000000000b
      BEQ NumeroNegativo
      BX LR
      ;;endTrataNegativo
      
NumeroNegativo
      MVN R1, R1
      ADD R1, #1
      MOV R8, R1  
      MOV R12, #1
      BX LR
      ;;endNumeroNegativo
   
SerialPrint
      MOV R6, #0
      PUSH {LR}
      CMP R12, #1
      IT EQ
        BLEQ PrintNegativo
      POP {LR}
      POP {R1} 
      ADD R1, #48
      PUSH {LR}
      BL Transmite
      POP {LR}
      SUBS R1, #48
      SUBS R7, #1
      CMP R7, R6
      IT EQ
        BXEQ LR 
      
loopPrint
      POP {R7}
      MUL R1, R9
      SUBS R1, R7, R1
      PUSH {R7}
      PUSH {LR}
      ADD R1, #48 ;; converte ASCII
      BL Transmite
      POP {LR}
      SUBS R1, #48 ;;converte ASCII
      POP {R1}
      
      CMP R8, R1
      IT EQ
        BXEQ LR
        
      CMP R8, R7
      IT EQ
        BXEQ LR
      
      CMP R7, R6
      IT EQ
        BXEQ LR 
      
      B loopPrint
      ;;end

PrintNegativo
      PUSH {R1}
      MOV R1, #'-'
      PUSH {LR}
      BL Transmite
      POP {LR}
      POP {R1}
      BX LR
      ;;endPrintNegativo

ValidaCaracter:        
        CMP R1, #'0' 
        BEQ Length        
        CMP R1, #'1' 
        BEQ Length                
        CMP R1, #'2' 
        BEQ Length                
        CMP R1, #'3' 
        BEQ Length                
        CMP R1, #'4' 
        BEQ Length                
        CMP R1, #'5' 
        BEQ Length        
        CMP R1, #'6' 
        BEQ Length               
        CMP R1, #'7' 
        BEQ Length                
        CMP R1, #'8' 
        BEQ Length               
        CMP R1, #'9' 
        BEQ Length
        CMP R1, #'='
        BEQ wtx
        CMP R10, #0
        BEQ ValidaOp
                
        B wrx
        ;;endValidaCaracter
        
ValidaOp
        CMP R1, #'+' 
        BEQ wtx                
        CMP R1, #'-' 
        BEQ wtx                
        CMP R1, #'*' 
        BEQ wtx        
        CMP R1, #'/' 
        BEQ wtx        
        
        B wrx
        ;;endValidaCaracter
      
Length
        CMP R11, #4
        BEQ wrx
        
        B wtx
        ;;endLength

SemConta:
     MOV R1, R3
     BX LR
     ;;endSemConta
     
Soma:
     MOV R1, R3
     ADD R1, R4
     BX LR
     ;;endSoma
  
Subtrai:
     MOV R1, R4
     SUBS R1, R3
     BX LR
     ;;endSubtrai

Multiplica:
     MOV R1, R3
     MULS R1, R4
     BX LR 
     ;;endMultiplica

Divide:
     MOV R1, R4
     CMP R3, #0
     IT EQ
       BEQ MsgErro
     SDIV R1, R3
     BX LR   
     ;;endDivide

;----------
; UART_enable: habilita clock para as UARTs selecionadas em R2
; R2 = padrão de bits de habilitação das UARTs
; Destrói: R0 e R1
UART_enable:
        LDR R0, =SYSCTL_BASE
	LDR R1, [R0, #SYSCTL_RCGCUART]
	ORR R1, R2 ; habilita UARTs selecionados
	STR R1, [R0, #SYSCTL_RCGCUART]

waitu	LDR R1, [R0, #SYSCTL_PRUART]
	TEQ R1, R2 ; clock das UARTs habilitados?
	BNE waitu

        BX LR
        
; UART_config: configura a UART desejada
; R0 = endereço base da UART desejada
; Destrói: R1
UART_config:
        LDR R1, [R0, #UART_CTL]
        BIC R1, #0x01 ; desabilita UART (bit UARTEN = 0)
        STR R1, [R0, #UART_CTL]

        ;RNF1 -> clock = 16MHz, baud rate = 14400 bps 
        MOV R1, #69
        STR R1, [R0, #UART_IBRD]
        MOV R1, #28
        STR R1, [R0, #UART_FBRD]
        
        ;RNF1 -> 7 bits, 1 stop, parity even, FIFOs disabled, no interrupts
        MOV R1, #0x46
        STR R1, [R0, #UART_LCRH]
        
        ; clock source = system clock
        MOV R1, #0x00
        STR R1, [R0, #UART_CC]
        
        LDR R1, [R0, #UART_CTL]
        ORR R1, #0x01 ; habilita UART (bit UARTEN = 1)
        STR R1, [R0, #UART_CTL]

        BX LR


; GPIO_special: habilita funcões especiais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como funções especiais
; Destrói: R2
GPIO_special:
	LDR R2, [R0, #GPIO_AFSEL]
	ORR R2, R1 ; configura bits especiais
	STR R2, [R0, #GPIO_AFSEL]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

        BX LR

; GPIO_select: seleciona funcões especiais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem alterados
; R2 = padrão de bits (1) a serem selecionados como funções especiais
; Destrói: R3
GPIO_select:
	LDR R3, [R0, #GPIO_PCTL]
        BIC R3, R1
	ORR R3, R2 ; seleciona bits especiais
	STR R3, [R0, #GPIO_PCTL]

        BX LR
;----------

; GPIO_enable: habilita clock para os ports de GPIO selecionados em R2
; R2 = padrão de bits de habilitação dos ports
; Destrói: R0 e R1
GPIO_enable:
        LDR R0, =SYSCTL_BASE
	LDR R1, [R0, #SYSCTL_RCGCGPIO]
	ORR R1, R2 ; habilita ports selecionados
	STR R1, [R0, #SYSCTL_RCGCGPIO]

waitg	LDR R1, [R0, #SYSCTL_PRGPIO]
	TEQ R1, R2 ; clock dos ports habilitados?
	BNE waitg

        BX LR

; GPIO_digital_output: habilita saídas digitais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como saídas digitais
; Destrói: R2
GPIO_digital_output:
	LDR R2, [R0, #GPIO_DIR]
	ORR R2, R1 ; configura bits de saída
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

        BX LR

; GPIO_write: escreve nas saídas do port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem acessados
; R2 = bits a serem escritos
GPIO_write:
        STR R2, [R0, R1, LSL #2] ; escreve bits com máscara de acesso
        BX LR

; GPIO_digital_input: habilita entradas digitais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como entradas digitais
; Destrói: R2
GPIO_digital_input:
	LDR R2, [R0, #GPIO_DIR]
	BIC R2, R1 ; configura bits de entrada
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

	LDR R2, [R0, #GPIO_PUR]
	ORR R2, R1 ; habilita resitor de pull-up
	STR R2, [R0, #GPIO_PUR]

        BX LR

; GPIO_read: lê as entradas do port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem acessados
; R2 = bits lidos
GPIO_read:
        LDR R2, [R0, R1, LSL #2] ; lê bits com máscara de acesso
        BX LR

; SW_delay: atraso de tempo por software
; R0 = valor do atraso
; Destrói: R0
SW_delay:
        CBZ R0, out_delay
        SUB R0, R0, #1
        B SW_delay        
out_delay:
        BX LR
        
;;Funcionalidades de msg 
Instrucao:
        PUSH {LR}
        LDR R3, =instrucao ; ponteiro de origem
        MOV R5, #71

LoopInstrucao
        LDR R1, [R3] ; leitura
        BL Transmite ;
        ADD R3, #1
        SUBS R5, #1
        CBZ R5, RetornaInstrucao
        B LoopInstrucao
        
RetornaInstrucao
        BL QuebraDeLinha
        POP {LR}
        BX LR        
        ;;endInstrução

Insira:
        PUSH {LR}
        LDR R3, =insira ; ponteiro de origem
        MOV R5, #20

LoopInsira
        LDR R1, [R3] ; leitura
        BL Transmite ;
        ADD R3, #1
        SUBS R5, #1
        CBZ R5, RetornaInsira
        B LoopInsira
        
RetornaInsira
        BL QuebraDeLinha
        POP {LR}
        BX LR
        ;;endInsira

MsgErro:
        LDR R3, =msgErro ; ponteiro de origem
        MOV R5, #38

LoopMsgErro
        LDR R1, [R3] ; leitura
        BL Transmite ;
        ADD R3, #1
        SUBS R5, #1
        CBZ R5, RetornaMsgErro
        B LoopMsgErro
        
RetornaMsgErro
        BL QuebraDeLinha
        BL Insira
        MOV R10, #0
        B loop      
        ;;endMsgErro

QuebraDeLinha:
        PUSH {LR}
        LDR R3, =lf ; ponteiro de origem
        LDR R1, [R3] ; leitura
        BL Transmite ;
        LDR R3, =cr ; ponteiro de origem
        LDR R1, [R3] ; leitura
        BL Transmite ;
        POP {LR}
        BX LR      
        ;;endQuebraDeLinha
        
Transmite:
        STR R1, [R0] ; transmite ao registrador de dados da UART0
        
        PUSH {R0}
        MOV R0, #0x2000 ; delay
        PUSH {LR}
        BL SW_delay
        POP {LR}
        POP {R0}
        
        BX LR
        ;;endTransmite

;=========seção de constantes em ROM=========;

        SECTION .rodata:CONST(2)
        DATA
instrucao   DC8  "Instrucao: digite a operacao desejada e tecle '=' para executar a conta"
insira      DC8  "Insira uma operacao:"
msgErro     DC8  " Erro. Divisao por zero nao permitida!"
lf          DC8  00001010b
cr          DC8  00001101b

        ;; Forward declaration of sections.
        SECTION CSTACK:DATA:NOROOT(3)
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Interrupt vector table.
;;

        SECTION .intvec:CODE:NOROOT(2)
        
        DATA

__vector_table
        DCD     sfe(CSTACK)
        DCD     __iar_program_start

        DCD     NMI_Handler
        DCD     HardFault_Handler
        DCD     MemManage_Handler
        DCD     BusFault_Handler
        DCD     UsageFault_Handler
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     SVC_Handler
        DCD     DebugMon_Handler
        DCD     0
        DCD     PendSV_Handler
        DCD     SysTick_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Default interrupt handlers.
;;

        PUBWEAK NMI_Handler
        PUBWEAK HardFault_Handler
        PUBWEAK MemManage_Handler
        PUBWEAK BusFault_Handler
        PUBWEAK UsageFault_Handler
        PUBWEAK SVC_Handler
        PUBWEAK DebugMon_Handler
        PUBWEAK PendSV_Handler
        PUBWEAK SysTick_Handler

        SECTION .text:CODE:REORDER:NOROOT(1)
        THUMB

NMI_Handler
HardFault_Handler
MemManage_Handler
BusFault_Handler
UsageFault_Handler
SVC_Handler
DebugMon_Handler
PendSV_Handler
SysTick_Handler
Default_Handler
__default_handler
        CALL_GRAPH_ROOT __default_handler, "interrupt"
        NOCALL __default_handler
        B __default_handler

        END
