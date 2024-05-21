/*
 * Copyright (c) 2013-2019 Huawei Technologies Co., Ltd. All rights reserved.
 * Copyright (c) 2020-2021 Huawei Device Co., Ltd. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of
 *    conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list
 *    of conditions and the following disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used
 *    to endorse or promote products derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "los_arch_regs.h"
#include "los_arch_macro.h"


.section .text
.literal_position
.align 4
.type HalTaskContextSwitch, @function
.global HalTaskContextSwitch
HalTaskContextSwitch:

    addi    sp, sp, -CONTEXT_SIZE   /* 手动调整堆栈指针 */
    addi    a2, sp, 0
    PUSH_ALL_REG a2                 /* 保存所有寄存器 */
    call0   SaveRetAddr             /* 保存返回地址 */
    beqi    a3, 1, .switchdone      /* 检查是否需要切换任务 */
    
    movi    a4, g_losTask
    l32i    a5, a4, 0               /* 获取当前运行的任务 */
    s32i    a2, a5, 0               /* 存储堆栈指针 */
    l32i    a5, a4, 4               /* 获取新任务 */
    s32i    a5, a4, 0               /* 设置运行任务为新任务 */
    l32i    a4, a5, 0               /* 获取新任务的堆栈指针 */
    
    rsr     a5, PS                  /* 读取程序状态寄存器 */
    movi    a3, ~(0x1F)             /* 清除LEVEL_MASK位，ESP8266中没有WOE_ENABLE */

    and     a2, a5, a3              /* 清除WOE和LEVEL_MASK位 */
    addi    a2, a2, 3
    wsr     a2, PS                  /* 写入程序状态寄存器 */
    rsync
    
    //; 由于ESP8266没有窗口机制，省略SpillWindow调用
    
    mov     sp, a4                  /* 恢复新任务的堆栈指针 */
    POP_ALL_REG a2        /* 恢复所有寄存器 */
    rfi     0                       /* 返回中断 */
    
.switchdone:
    ret                            /* 返回 */


.type HakSpillWindow, @function
.global HakSpillWindow
HakSpillWindow:

   
    addi    a2, sp, -CONTEXT_SIZE
    PUSH_ALL_REG a2
    
    rsr     a5, PS
    movi    a3, ~(0x1F) 
    and     a3, a5, a3
    addi    a3, a3, LEVEL3
    wsr     a3, PS
    rsync

    mov     a4, a2


    l32i    a5, a4, CONTEXT_OFF_PS /* restroe PS */
    wsr     a5, PS
    rsync
    l32i    a0, a4, CONTEXT_OFF_A0
    l32i    a1, a4, CONTEXT_OFF_A1

    ret

.type OsStartToRun, @function
.global OsStartToRun
OsStartToRun:

    movi    a2, g_losTask
    l32i    a3, a2, 4   /* get new task */
    l32i    sp, a3, 0   /* get sp */

    rsr     a4, PS
    movi    a3, ~(0x1F) 
    and     a2, a4, a3
    addi    a2, a2, LEVEL3
    wsr     a2, PS
    rsync

    mov     a5, a1
    l32i    a1, a1, CONTEXT_OFF_A1


    mov     a2, a5
    POP_ALL_REG a2 
    rfi     0

.global SaveRetAddr
.type   SaveRetAddr, @function
.literal_position
.align  4

SaveRetAddr:

    movi    a3, 1
    s32i    a3, a2, CONTEXT_OFF_A3
    s32i    a0, a2, CONTEXT_OFF_PC    /* save pc */
    movi    a3, 0
    ret
