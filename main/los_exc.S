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

.extern HalInterrupt
.extern UserException

.section    .iram,"ax"
.literal_position
.type       HandleEntry,@function
.align      4
HandleEntry:

    /* 保存当前堆栈指针到a0，并调整堆栈大小 */
    mov     a0, sp
    addi    sp, sp, -CONTEXT_SIZE

    /* 保存所有寄存器 */
    PUSH_ALL_REG sp

    /* 保存旧堆栈指针 */
    s32i    a0, sp, CONTEXT_OFF_A1
    
    /* 保存 EPC1 和 EXCSAVE1 */
    rsr     a0, EPC1
    s32i    a0, sp, CONTEXT_OFF_PC
    rsr     a0, EXCSAVE1
    s32i    a0, sp, CONTEXT_OFF_A0

    /* 设置异常保存寄存器 */
    wsr     sp, EXCSAVE1
    l32i    a1, sp, CONTEXT_OFF_A1

    /* 不使用 SpillWindow，直接处理异常 */

    /* 保存 EXCCAUSE 和 EXCVADDR */
    rsr     a0, EXCCAUSE
    s32i    a0, sp, CONTEXT_OFF_EXCCAUSE
    rsr     a0, EXCVADDR
    s32i    a0, sp, CONTEXT_OFF_EXCVADDR

    /* 设置 PS 寄存器 */
    movi    a0, INT_MASK | USER_VECTOR_MODE | WOE_ENABLE
    wsr     a0, PS
    rsync

    /* 设置异常处理相关寄存器 */
    rsr     a6, EPC1
    mov     a7, sp
    rsr     a8, EXCCAUSE

    /* 调用异常处理函数 */
    call0   HalExcHandleEntry

1:
    j       1b

.begin      literal_prefix .DebugExceptionHandler
.section    .DebugExceptionHandler.text, "ax"
.type       DebugExceptionHandler,@function
.global     DebugExceptionHandler
.align      4
.literal_position
DebugExceptionHandler:

    call0   UserException

.end        literal_prefix

.begin      literal_prefix .NMIExceptionHandler
.section    .NMIExceptionHandler.text, "ax"
.type       NMIExceptionHandler,@function
.global     NMIExceptionHandler
.align      4
.literal_position
NMIExceptionHandler:

    call0   UserException

.end        literal_prefix

.begin      literal_prefix .DoubleExceptionHandler
.section    .DoubleExceptionHandler.text, "ax"
.type       DoubleExceptionHandler,@function
.global     DoubleExceptionHandler
.align      4
.literal_position
DoubleExceptionHandler:

    call0   UserException

.end        literal_prefix

.begin      literal_prefix .KernelExceptionHandler
.section    .KernelExceptionHandler.text, "ax"
.type       KernelExceptionHandler,@function
.global     KernelExceptionHandler
.align      4
.literal_position
KernelExceptionHandler:

    wsr     a0, EXCSAVE1
    call0   KernelException

.end        literal_prefix

.section .iram,"ax"
.align      4
KernelException:

    movi    a0,5
    wsr     a0,EXCCAUSE
    call0   UserException
    rfe

.begin      literal_prefix .UserExceptionHandler
.section    .UserExceptionHandler.text, "ax"
.global     UserExceptionHandler
.type       UserExceptionHandler,@function
.align      4
.literal_position
UserExceptionHandler:

    wsr     a0, EXCSAVE1
    call0   UserException

.end        literal_prefix

.section    .iram,"ax"
.type       UserException,@function
.align      4
UserException:

    rsr     a0, EXCCAUSE
    beqi    a0, LEVEL1_TINRERRUPT_CAUSE, InterruptEntry1
    beqi    a0, ALLOC_CAUSE, AllocHandel
    call0   HandleEntry
1:
    j 1b

.section    .iram,"ax"
.type       AllocHandel,@function
.align      4
AllocHandel:
    call0 AllocHandelEntry

.section    .iram,"ax"
.type       InterruptEntry1,@function
.align      4
InterruptEntry1:

    mov     a0, sp
    addi    sp, sp, -CONTEXT_SIZE

    PUSH_ALL_REG a1

    s32i    a0, sp, CONTEXT_OFF_A1
    rsr     a0, EPC1
    s32i    a0, sp, CONTEXT_OFF_PC
    rsr     a0, EXCSAVE1
    s32i    a0, sp, CONTEXT_OFF_A0

    wsr     a1, EXCSAVE1
    l32i    a1, a1, CONTEXT_OFF_A1
    //call0   SpillWindow
    rsr     a1, EXCSAVE1
    
    movi    a0, LEVEL1_INT_MASK | USER_VECTOR_MODE | WOE_ENABLE
    wsr     a0, PS
    rsync

    call0   HalInterrupt
    mov     a2, a1
    POP_ALL_REG a2 
    rfe    

.begin      literal_prefix .InterruptEntry2
.section    .InterruptEntry2.text, "ax"
.global     InterruptEntry2
.type       InterruptEntry2,@function
.align      4
.literal_position
InterruptEntry2:

    wsr     a0, EXCSAVE2
    movi    a4, LEVEL2
    call0   HandleEntry

.end        literal_prefix

.begin      literal_prefix .InterruptEntry3
.section    .InterruptEntry3.text, "ax"
.global     InterruptEntry3
.type       InterruptEntry3,@function
.align      4
.literal_position
InterruptEntry3:

    wsr     a0, EXCSAVE3
    movi    a4, LEVEL3
    call0   HandleEntry

.end        literal_prefix

.begin      literal_prefix .InterruptEntry4
.section    .InterruptEntry4.text, "ax"
.global     InterruptEntry4
.type       InterruptEntry4,@function
.align      4
.literal_position
InterruptEntry4:

    mov     a0, sp
    addi    sp, sp, -CONTEXT_SIZE

    /* 保存所有寄存器 */
    PUSH_ALL_REG sp

    /* 保存当前堆栈指针到 EXCSAVE */
    wsr     a0, EXCSAVE1

    /* 保存 EPC 到上下文 */
    rsr     a0, EPC1
    s32i    a0, sp, CONTEXT_OFF_PC

    /* 调用处理入口 */
    movi    a4, LEVEL4
    call0   HandleEntry

    /* 恢复所有寄存器 */
    POP_ALL_REG sp

    /* 恢复堆栈指针并返回 */
    mov     sp, a0
    rfe

.end        literal_prefix

.begin      literal_prefix .InterruptEntry5
.section    .InterruptEntry5.text, "ax"
.global     InterruptEntry5
.type       InterruptEntry5,@function
.align      4
.literal_position
InterruptEntry5:

    mov     a0, sp
    addi    sp, sp, -CONTEXT_SIZE

    /* 保存所有寄存器 */
    PUSH_ALL_REG sp

    /* 保存当前堆栈指针到 EXCSAVE */
    wsr     a0, EXCSAVE1

    /* 保存 EPC 到上下文 */
    rsr     a0, EPC1
    s32i    a0, sp, CONTEXT_OFF_PC

    /* 调用处理入口 */
    movi    a4, LEVEL5
    call0   HandleEntry

    /* 恢复所有寄存器 */
    POP_ALL_REG sp

    /* 恢复堆栈指针并返回 */
    mov     sp, a0
    rfe

.end        literal_prefix

.section .iram,"ax"
.global OverFlowGroup1
.type OverFlowGroup1, @function
.align 4

OverFlowGroup1:
    /* 为堆栈指针减去16字节 */
    addi    a5, a5, -16

    /* 将寄存器a3, a2, a1, a0存储到堆栈 */
    s32i    a3, a5, 12
    s32i    a2, a5, 8
    s32i    a1, a5, 4
    s32i    a0, a5, 0

    /* 为堆栈指针加上16字节恢复原始位置 */
    addi    a5, a5, 16

    /* 返回异常帧 */
    rfe


.section .iram,"ax"
.global UnderFlowGroup1
.type UnderFlowGroup1, @function
.align 4

UnderFlowGroup1:
    /* 为堆栈指针减去16字节 */
    addi    a5, a5, -16

    /* 从堆栈中加载寄存器a3, a2, a1, a0的值 */
    l32i    a3, a5, 12
    l32i    a2, a5, 8
    l32i    a1, a5, 4
    l32i    a0, a5, 0

    /* 为堆栈指针加上16字节恢复原始位置 */
    addi    a5, a5, 16

    /* 返回异常帧 */
    rfe


.section .iram,"ax"
.global OverFlowGroup2
.type OverFlowGroup2, @function
.align 4

OverFlowGroup2:
    /* 为堆栈指针减去16字节 */
    addi    a9, a9, -16

    /* 将寄存器a3, a2, a1, a0存储到堆栈 */
    s32i    a3, a9, 12
    s32i    a2, a9, 8
    s32i    a1, a9, 4
    s32i    a0, a9, 0

    /* 为堆栈指针加上16字节恢复原始位置 */
    addi    a9, a9, 16

    /* 堆栈指针减去12字节，以备后续加载寄存器 */
    addi    a1, a1, -12

    /* 从堆栈中加载a0的值 */
    l32i    a0, a1, 0

    /* 恢复堆栈指针 */
    addi    a1, a1, 12

    /* 修改a0，准备存储a4-a7到新的堆栈位置 */
    addi    a0, a0, -32

    /* 将寄存器a7, a6, a5, a4存储到新的堆栈位置 */
    s32i    a7, a0, 12
    s32i    a6, a0, 8
    s32i    a5, a0, 4
    s32i    a4, a0, 0

    /* 返回异常帧 */
    rfe


.section .iram,"ax"
.global UnderFlowGroup2
.type UnderFlowGroup2, @function
.align 4

UnderFlowGroup2:
    /* 为堆栈指针减去16字节 */
    addi    a9, a9, -16

    /* 将寄存器a3, a2, a1, a0存储到堆栈 */
    l32i    a3, a9, 12
    l32i    a2, a9, 8
    l32i    a1, a9, 4
    l32i    a0, a9, 0

    /* 为堆栈指针加上16字节恢复原始位置 */
    addi    a9, a9, 16

    /* 堆栈指针减去12字节，以备后续加载寄存器 */
    addi    a1, a1, -12

    /* 从堆栈中加载a4的值 */
    l32i    a4, a1, 0

    /* 恢复堆栈指针 */
    addi    a1, a1, 12

    /* 修改a4，准备加载a7-a4到新的堆栈位置 */
    addi    a4, a4, -32

    /* 将寄存器a7, a6, a5, a4存储到新的堆栈位置 */
    l32i    a7, a4, 12
    l32i    a6, a4, 8
    l32i    a5, a4, 4
    l32i    a4, a4, 0

    /* 返回异常帧 */
    rfe
.section .iram,"ax"
.global OverFlowGroup3
.type OverFlowGroup3, @function
.align 4

OverFlowGroup3:
    /* 为堆栈指针减去16字节 */
    addi    a13, a13, -16

    /* 将寄存器a3, a2, a1, a0存储到堆栈 */
    s32i    a3, a13, 12
    s32i    a2, a13, 8
    s32i    a1, a13, 4
    s32i    a0, a13, 0

    /* 为堆栈指针加上16字节恢复原始位置 */
    addi    a13, a13, 16

    /* 堆栈指针减去12字节，以备后续加载寄存器 */
    addi    a1, a1, -12

    /* 从堆栈中加载a0的值 */
    l32i    a0, a1, 0

    /* 恢复堆栈指针 */
    addi    a1, a1, 12

    /* 修改a0，准备存储a4-a11到新的堆栈位置 */
    addi    a0, a0, -48

    /* 将寄存器a11-a4存储到新的堆栈位置 */
    s32i    a11, a0, 28
    s32i    a10, a0, 24
    s32i    a9, a0, 20
    s32i    a8, a0, 16
    s32i    a7, a0, 12
    s32i    a6, a0, 8
    s32i    a5, a0, 4
    s32i    a4, a0, 0

    /* 返回异常帧 */
    rfe


.section .iram,"ax"
.global UnderFlowGroup3
.type UnderFlowGroup3, @function
.align 4

UnderFlowGroup3:
    /* 为堆栈指针减去16字节 */
    addi    a13, a13, -16

    /* 从堆栈中加载a3, a2, a1, a0的值 */
    l32i    a3, a13, 12
    l32i    a2, a13, 8
    l32i    a1, a13, 4
    l32i    a0, a13, 0

    /* 为堆栈指针加上16字节恢复原始位置 */
    addi    a13, a13, 16

    /* 堆栈指针减去12字节，以备后续加载寄存器 */
    addi    a1, a1, -12

    /* 从堆栈中加载a4的值 */
    l32i    a4, a1, 0

    /* 恢复堆栈指针 */
    addi    a1, a1, 12

    /* 修改a4，准备加载a11-a5的值 */
    addi    a4, a4, -48

    /* 从堆栈中加载a11-a5的值 */
    l32i    a11, a4, 28
    l32i    a10, a4, 24
    l32i    a9, a4, 20
    l32i    a8, a4, 16
    l32i    a7, a4, 12
    l32i    a6, a4, 8
    l32i    a5, a4, 4

    /* 返回异常帧 */
    rfe


.section    .userVector,"ax"
.type       AllocHandelEntry,@function
.align      4
AllocHandelEntry:

    addi    a1, a1, -(CONTEXT_OFF_A4 - CONTEXT_OFF_A0)
    s32i    a2, a1, (CONTEXT_OFF_A2 - CONTEXT_OFF_A0)
    s32i    a3, a1, (CONTEXT_OFF_A3 - CONTEXT_OFF_A0)

    rsr     a0, PS
    rsr     a2, WINDOWBASE
    extui   a3, a0, PS_OWB_SHIFT, WINDOWBASEBITS
    xor     a3, a3, a2
    slli    a3, a3, PS_OWB_SHIFT
    xor     a0, a0, a3
    wsr     a0, PS
    rsr     a0, EXCSAVE1

    l32i    a2, a1, (CONTEXT_OFF_A2 - CONTEXT_OFF_A0)
    l32i    a3, a1, (CONTEXT_OFF_A3 - CONTEXT_OFF_A0)
    addi    a1, a1, (CONTEXT_OFF_A4 - CONTEXT_OFF_A0)
    rsync

    sr  a4, a4, 1        //; 将寄存器 a4 中的数据右移一位
    sbrcs a4, 31         // ; 如果右移后的结果最高位为 1，则跳转到右移完成后的处理部分
    seq a4, a4, a4       // ; 如果右移后的结果最高位为 0，则将寄存器 a4 清零

    test a4, (1 << HIGHBIT_CALLNMODE)    //; 测试第 HIGHBIT_CALLNMODE 位是否为 1
    bnez test_result, UnderFlowGroup1    // ; 如果结果不为零（即第 HIGHBIT_CALLNMODE 位为 1），跳转到 UnderFlowGroup1

    sr a4, a4, 1        //; 将寄存器 a4 中的数据右移一位
    sbrcs a4, 31          //; 如果右移后的结果最高位为 1，则跳转到右移完成后的处理部分
    seq a4, a4, a4        //; 如果右移后的结果最高位为 0，则将寄存器 a4 清零
    
    and a9, a8, LOWBIT_CALLNMODE     //; 将 a9 中的值设置为 a8 的最低位
    breq a9, zero, UnderFlowGroup2   //; 如果 a9 为零，则跳转到 UnderFlowGroup2 标签处执行相应的代码

    sr a4, a4, 1        //; 将寄存器 a4 中的数据右移一位
    sbrcs a4, 31         // ; 如果右移后的结果最高位为 1，则跳转到右移完成后的处理部分
    seq a4, a4, a4       // ; 如果右移后的结果最高位为 0，则将寄存器 a4 清零
    j       UnderFlowGroup3

.global EnableExceptionInterface
.section    .iram,"ax"
.type       EnableExceptionInterface,@function
.align      4
EnableExceptionInterface:
    entry   a1,16
    retw
