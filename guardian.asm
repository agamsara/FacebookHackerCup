section .data

filename:
    db "input.txt", 0

case_text:
    db "Case #"
case_text_len equ $ - case_text

colon_text:
    db ": "
colon_text_len equ $ - colon_text

newline:
    db 10


section .bss

file_fd:
    resq 1

queue:
    resd 1000000

buffer:
    resb 166777216

grid:
    resb 1000000

dist:
    resw 1000000

debug_char:
    resb 1

max_region:
    resq 1

current_region:
    resq 1


section .text
global _start


_start:

    ; ========================================================
    ; OPEN FILE
    ; ========================================================

    mov rax, 2
    mov rdi, filename
    xor rsi, rsi
    xor rdx, rdx
    syscall

    mov [file_fd], rax


    ; ========================================================
    ; READ FILE
    ; ========================================================

    xor rax, rax
    mov rdi, [file_fd]
    mov rsi, buffer
    mov rdx, 166777216
    syscall


    ; ========================================================
    ; PARSE T
    ; ========================================================

    mov rsi, buffer

    call parse_int
    mov r12, rax              ; T

    mov rbp, 1                ; case number


; ============================================================
; TEST CASE LOOP
; ============================================================

.test_case_loop:

    cmp rbp, r12
    ja .all_done


    ; ========================================================
    ; PARSE R, C, S
    ; ========================================================

    call parse_int
    mov r13, rax              ; R

    call parse_int
    mov r14, rax              ; C

    call parse_int
    mov r15, rax              ; S


    ; ========================================================
    ; R * C
    ; ========================================================

    mov rax, r13
    imul rax, r14

    mov r9, rax               ; total cells


    ; ========================================================
    ; COPY GRID INTO FLAT ARRAY
    ; ========================================================

    mov rdi, grid
    xor r8, r8


.copy_grid:

    cmp r8, r9
    je .grid_done

    mov al, byte [rsi]

    ; ignore newline
    cmp al, 10
    je .skip_grid_char

    ; ignore carriage return too
    cmp al, 13
    je .skip_grid_char

    mov byte [rdi], al

    inc rdi
    inc r8


.skip_grid_char:

    inc rsi
    jmp .copy_grid


.grid_done:


    ; ========================================================
    ; INITIALIZE DIST[] = INF
    ; ========================================================

    xor r8, r8


.init_dist:

    cmp r8, r9
    je .dist_ready

    mov word [dist + r8*2], 0xFFFF

    inc r8
    jmp .init_dist


.dist_ready:


    ; ========================================================
    ; INITIAL DANGER CELLS
    ;
    ; #      -> 0
    ; border -> 1
    ; other  -> INF
    ; ========================================================

    xor r8, r8


.check_cells:

    cmp r8, r9
    je .done_checking


    ; object?
    cmp byte [grid + r8], '#'
    je .is_object


    ; calculate row / column
    mov rax, r8
    xor rdx, rdx
    div r14

    ; rax = row
    ; rdx = col


    ; row == 0
    test rax, rax
    jz .is_border


    ; row == R - 1
    mov r10, r13
    dec r10

    cmp rax, r10
    je .is_border


    ; col == 0
    test rdx, rdx
    jz .is_border


    ; col == C - 1
    mov r10, r14
    dec r10

    cmp rdx, r10
    je .is_border


    jmp .next_cell


.is_object:

    mov word [dist + r8*2], 0
    jmp .next_cell


.is_border:

    mov word [dist + r8*2], 1


.next_cell:

    inc r8
    jmp .check_cells


.done_checking:


    ; ========================================================
    ; BUILD DANGER BFS QUEUE
    ; ========================================================

    xor r10, r10              ; head
    xor r11, r11              ; tail
    xor r8, r8


.fill_queue:

    cmp r8, r9
    je .queue_ready

    mov ax, word [dist + r8*2]

    cmp ax, 0
    je .enqueue_danger

    cmp ax, 1
    je .enqueue_danger

    jmp .next_queue_cell


.enqueue_danger:

    mov dword [queue + r11*4], r8d
    inc r11


.next_queue_cell:

    inc r8
    jmp .fill_queue


.queue_ready:

    xor r10, r10              ; head = 0


; ============================================================
; DANGER BFS
; ============================================================

.danger_bfs:

    cmp r10, r11
    je .danger_bfs_done


    ; dequeue
    mov eax, dword [queue + r10*4]
    inc r10

    mov r8, rax


    ; --------------------------------------------------------
    ; if dist[current] >= S:
    ;     don't expand
    ; --------------------------------------------------------

    movzx rcx, word [dist + r8*2]

    cmp rcx, r15
    jae .danger_next


    ; calculate row / col
    mov rax, r8
    xor rdx, rdx
    div r14

    ; r8  = index
    ; rax = row
    ; rdx = col


    ; ========================================================
    ; RIGHT
    ; ========================================================

    mov rcx, r14
    dec rcx

    cmp rdx, rcx
    je .danger_no_right

    mov rbx, r8
    inc rbx

    cmp word [dist + rbx*2], 0xFFFF
    jne .danger_no_right

    mov cx, word [dist + r8*2]
    inc cx

    mov word [dist + rbx*2], cx

    mov dword [queue + r11*4], ebx
    inc r11


.danger_no_right:


    ; ========================================================
    ; LEFT
    ; ========================================================

    test rdx, rdx
    jz .danger_no_left

    mov rbx, r8
    dec rbx

    cmp word [dist + rbx*2], 0xFFFF
    jne .danger_no_left

    mov cx, word [dist + r8*2]
    inc cx

    mov word [dist + rbx*2], cx

    mov dword [queue + r11*4], ebx
    inc r11


.danger_no_left:


    ; ========================================================
    ; UP
    ; ========================================================

    test rax, rax
    jz .danger_no_up

    mov rbx, r8
    sub rbx, r14

    cmp word [dist + rbx*2], 0xFFFF
    jne .danger_no_up

    mov cx, word [dist + r8*2]
    inc cx

    mov word [dist + rbx*2], cx

    mov dword [queue + r11*4], ebx
    inc r11


.danger_no_up:


    ; ========================================================
    ; DOWN
    ; ========================================================

    mov rcx, r13
    dec rcx

    cmp rax, rcx
    je .danger_no_down

    mov rbx, r8
    add rbx, r14

    cmp word [dist + rbx*2], 0xFFFF
    jne .danger_no_down

    mov cx, word [dist + r8*2]
    inc cx

    mov word [dist + rbx*2], cx

    mov dword [queue + r11*4], ebx
    inc r11


.danger_no_down:


.danger_next:

    jmp .danger_bfs


.danger_bfs_done:


    ; ========================================================
    ; FIND LARGEST SAFE REGION
    ;
    ; 0xFFFF = safe + unvisited
    ; 0xFFFE = safe + visited
    ; ========================================================

    mov qword [max_region], 0

    xor rdi, rdi              ; scan index


.find_safe:

    cmp rdi, r9
    je .regions_done

    cmp word [dist + rdi*2], 0xFFFF
    je .start_region

    inc rdi
    jmp .find_safe


; ============================================================
; START ONE REGION
; ============================================================

.start_region:

    xor r10, r10              ; head
    xor r11, r11              ; tail

    mov qword [current_region], 0


    ; enqueue first cell
    mov dword [queue], edi
    inc r11


    ; mark visited
    mov word [dist + rdi*2], 0xFFFE


; ============================================================
; REGION BFS
; ============================================================

.region_bfs:

    cmp r10, r11
    je .region_done


    ; dequeue
    mov eax, dword [queue + r10*4]
    inc r10

    mov r8, rax


    ; region_size++
    inc qword [current_region]


    ; row / col
    mov rax, r8
    xor rdx, rdx
    div r14


    ; ========================================================
    ; RIGHT
    ; ========================================================

    mov rcx, r14
    dec rcx

    cmp rdx, rcx
    je .region_no_right

    mov rbx, r8
    inc rbx

    cmp word [dist + rbx*2], 0xFFFF
    jne .region_no_right

    mov word [dist + rbx*2], 0xFFFE

    mov dword [queue + r11*4], ebx
    inc r11


.region_no_right:


    ; ========================================================
    ; LEFT
    ; ========================================================

    test rdx, rdx
    jz .region_no_left

    mov rbx, r8
    dec rbx

    cmp word [dist + rbx*2], 0xFFFF
    jne .region_no_left

    mov word [dist + rbx*2], 0xFFFE

    mov dword [queue + r11*4], ebx
    inc r11


.region_no_left:


    ; ========================================================
    ; UP
    ; ========================================================

    test rax, rax
    jz .region_no_up

    mov rbx, r8
    sub rbx, r14

    cmp word [dist + rbx*2], 0xFFFF
    jne .region_no_up

    mov word [dist + rbx*2], 0xFFFE

    mov dword [queue + r11*4], ebx
    inc r11


.region_no_up:


    ; ========================================================
    ; DOWN
    ; ========================================================

    mov rcx, r13
    dec rcx

    cmp rax, rcx
    je .region_no_down

    mov rbx, r8
    add rbx, r14

    cmp word [dist + rbx*2], 0xFFFF
    jne .region_no_down

    mov word [dist + rbx*2], 0xFFFE

    mov dword [queue + r11*4], ebx
    inc r11


.region_no_down:

    jmp .region_bfs


; ============================================================
; FINISHED ONE REGION
; ============================================================

.region_done:

    mov rax, [current_region]

    cmp rax, [max_region]
    jbe .not_new_max

    mov [max_region], rax


.not_new_max:

    inc rdi
    jmp .find_safe


; ============================================================
; FINISHED ALL REGIONS
; ============================================================

.regions_done:


    ; ========================================================
    ; PRINT:
    ;
    ; Case #N: answer
    ; ========================================================

    push rsi
    ; "Case #"
    mov rax, 1
    mov rdi, 1
    mov rsi, case_text
    mov rdx, case_text_len
    syscall


    ; case number
    mov rax, rbp
    call print_int


    ; ": "
    mov rax, 1
    mov rdi, 1
    mov rsi, colon_text
    mov rdx, colon_text_len
    syscall


    ; answer
    mov rax, [max_region]
    call print_int


    ; newline
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rsi

    ; next test case
    inc rbp
    jmp .test_case_loop


; ============================================================
; ALL TEST CASES DONE
; ============================================================

.all_done:

    mov rax, 3
    mov rdi, [file_fd]
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall



; ============================================================
; parse_int
;
; Input:
;   rsi = pointer somewhere before integer
;
; Output:
;   rax = integer
;   rsi = pointer after integer/delimiters
; ============================================================

parse_int:

    ; --------------------------------------------------------
    ; skip spaces / newlines / carriage returns
    ; --------------------------------------------------------

.skip_delimiters:

    mov al, byte [rsi]

    cmp al, ' '
    je .skip_one

    cmp al, 10
    je .skip_one

    cmp al, 13
    je .skip_one

    jmp .parse_start


.skip_one:

    inc rsi
    jmp .skip_delimiters


.parse_start:

    xor r8, r8


.parse_loop:

    movzx rax, byte [rsi]

    cmp rax, '0'
    jb .parse_done

    cmp rax, '9'
    ja .parse_done

    sub rax, '0'

    imul r8, r8, 10
    add r8, rax

    inc rsi
    jmp .parse_loop


.parse_done:

    mov rax, r8
    ret



; ============================================================
; print_int
;
; Input:
;   rax = unsigned integer
; ============================================================

print_int:

    xor rcx, rcx
    mov rbx, 10


    ; special case 0
    test rax, rax
    jnz .convert_digits


    mov byte [debug_char], '0'

    mov rax, 1
    mov rdi, 1
    mov rsi, debug_char
    mov rdx, 1
    syscall

    ret


.convert_digits:

    xor rdx, rdx
    div rbx

    push rdx

    inc rcx

    test rax, rax
    jnz .convert_digits


.print_digits:

    pop rdx

    add dl, '0'
    mov byte [debug_char], dl

    ; syscall destroys rcx, so preserve it
    push rcx

    mov rax, 1
    mov rdi, 1
    mov rsi, debug_char
    mov rdx, 1
    syscall

    pop rcx

    dec rcx
    jnz .print_digits

    ret
