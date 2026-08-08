#!/usr/bin/env python3
"""Tiny assembler for the SuperMIPS educational ISA.

Supported instructions:
  ADD SUB MUL DIV rd, rs, rt
  ADDI SUBI rt, rs, imm
  LUI rt, imm
  LW SW rt, offset(rs)
  BEQ rs, rt, label|offset
  J JAL label|word_index
  JR rs
  .word value
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys
from dataclasses import dataclass

OP = {
    "J": 0b000010,
    "JAL": 0b000011,
    "BEQ": 0b000100,
    "ADDI": 0b001000,
    "SUBI": 0b001001,
    "LUI": 0b001111,
    "LW": 0b100011,
    "SW": 0b101011,
}
FUNCT = {
    "JR": 0b001000,
    "ADD": 0b100000,
    "SUB": 0b100010,
    "MUL": 0b011000,
    "DIV": 0b011010,
}

@dataclass(frozen=True)
class SourceLine:
    number: int
    text: str
    instruction: str
    word_index: int


def strip_comment(line: str) -> str:
    positions = [p for marker in ("//", "#", ";") if (p := line.find(marker)) >= 0]
    if positions:
        line = line[: min(positions)]
    return line.strip()


def parse_int(token: str) -> int:
    token = token.strip().replace("_", "")
    try:
        return int(token, 0)
    except ValueError as exc:
        raise ValueError(f"invalid integer '{token}'") from exc


def parse_reg(token: str) -> int:
    token = token.strip().upper()
    if token.startswith("$"):
        token = "R" + token[1:]
    if not token.startswith("R"):
        raise ValueError(f"invalid register '{token}' (expected R0..R31)")
    value = parse_int(token[1:])
    if not 0 <= value <= 31:
        raise ValueError(f"register out of range: R{value}")
    return value


def split_operands(text: str) -> list[str]:
    return [part.strip() for part in text.split(",") if part.strip()]


def check_signed16(value: int, context: str) -> int:
    if not -32768 <= value <= 32767:
        raise ValueError(f"{context} immediate {value} does not fit signed 16 bits")
    return value & 0xFFFF


def check_u26(value: int, context: str) -> int:
    if not 0 <= value < (1 << 26):
        raise ValueError(f"{context} target {value} does not fit 26 bits")
    return value


def enc_r(rs: int, rt: int, rd: int, funct: int) -> int:
    return (rs << 21) | (rt << 16) | (rd << 11) | funct


def enc_i(op: int, rs: int, rt: int, imm: int) -> int:
    return (op << 26) | (rs << 21) | (rt << 16) | (imm & 0xFFFF)


def enc_j(op: int, word_index: int) -> int:
    return (op << 26) | (word_index & 0x03FFFFFF)


def first_pass(path: pathlib.Path) -> tuple[list[SourceLine], dict[str, int]]:
    labels: dict[str, int] = {}
    source: list[SourceLine] = []
    pc = 0

    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        cleaned = strip_comment(raw)
        if not cleaned:
            continue

        rest = cleaned
        while ":" in rest:
            label, tail = rest.split(":", 1)
            label = label.strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", label):
                raise ValueError(f"{path}:{number}: invalid label '{label}'")
            key = label.upper()
            if key in labels:
                raise ValueError(f"{path}:{number}: duplicate label '{label}'")
            labels[key] = pc
            rest = tail.strip()
            if not rest:
                break
        if not rest:
            continue

        source.append(SourceLine(number, raw.rstrip(), rest, pc))
        pc += 1

    return source, labels


def assemble_one(line: SourceLine, labels: dict[str, int]) -> int:
    parts = line.instruction.strip().split(None, 1)
    mnemonic = parts[0].upper()
    operand_text = parts[1] if len(parts) == 2 else ""
    ops = split_operands(operand_text)

    if mnemonic == ".WORD":
        if len(ops) != 1:
            raise ValueError(".word expects one value")
        return parse_int(ops[0]) & 0xFFFFFFFF

    if mnemonic in {"ADD", "SUB", "MUL", "DIV"}:
        if len(ops) != 3:
            raise ValueError(f"{mnemonic} expects rd, rs, rt")
        rd, rs, rt = map(parse_reg, ops)
        return enc_r(rs, rt, rd, FUNCT[mnemonic])

    if mnemonic == "JR":
        if len(ops) != 1:
            raise ValueError("JR expects rs")
        return enc_r(parse_reg(ops[0]), 0, 0, FUNCT["JR"])

    if mnemonic in {"ADDI", "SUBI"}:
        if len(ops) != 3:
            raise ValueError(f"{mnemonic} expects rt, rs, imm")
        rt, rs = parse_reg(ops[0]), parse_reg(ops[1])
        imm = check_signed16(parse_int(ops[2]), mnemonic)
        return enc_i(OP[mnemonic], rs, rt, imm)

    if mnemonic == "LUI":
        if len(ops) != 2:
            raise ValueError("LUI expects rt, imm")
        rt = parse_reg(ops[0])
        imm_value = parse_int(ops[1])
        if not -32768 <= imm_value <= 0xFFFF:
            raise ValueError(f"LUI immediate {imm_value} does not fit 16 bits")
        return enc_i(OP["LUI"], 0, rt, imm_value & 0xFFFF)

    if mnemonic in {"LW", "SW"}:
        if len(ops) != 2:
            raise ValueError(f"{mnemonic} expects rt, offset(rs)")
        rt = parse_reg(ops[0])
        match = re.fullmatch(r"\s*([^()]+)\(([^()]+)\)\s*", ops[1])
        if not match:
            raise ValueError(f"invalid memory operand '{ops[1]}'")
        offset = check_signed16(parse_int(match.group(1)), mnemonic)
        rs = parse_reg(match.group(2))
        return enc_i(OP[mnemonic], rs, rt, offset)

    if mnemonic == "BEQ":
        if len(ops) != 3:
            raise ValueError("BEQ expects rs, rt, label|offset")
        rs, rt = parse_reg(ops[0]), parse_reg(ops[1])
        target_token = ops[2].upper()
        if target_token in labels:
            offset_value = labels[target_token] - (line.word_index + 1)
        else:
            offset_value = parse_int(ops[2])
        offset = check_signed16(offset_value, "BEQ")
        return enc_i(OP["BEQ"], rs, rt, offset)

    if mnemonic in {"J", "JAL"}:
        if len(ops) != 1:
            raise ValueError(f"{mnemonic} expects label|word_index")
        target_token = ops[0].upper()
        target = labels[target_token] if target_token in labels else parse_int(ops[0])
        return enc_j(OP[mnemonic], check_u26(target, mnemonic))

    raise ValueError(f"unsupported mnemonic '{mnemonic}'")


def main() -> int:
    parser = argparse.ArgumentParser(description="Assemble SuperMIPS source into readmemh format")
    parser.add_argument("input", type=pathlib.Path)
    parser.add_argument("-o", "--output", required=True, type=pathlib.Path)
    parser.add_argument("--listing", type=pathlib.Path)
    args = parser.parse_args()

    try:
        source, labels = first_pass(args.input)
        words: list[int] = []
        listing_lines: list[str] = []
        for line in source:
            try:
                word = assemble_one(line, labels)
            except ValueError as exc:
                raise ValueError(f"{args.input}:{line.number}: {exc}") from exc
            words.append(word)
            listing_lines.append(f"{line.word_index * 4:08x}  {word:08x}  {line.text}")

        if not words:
            raise ValueError(f"{args.input}: no instructions found")

        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text("".join(f"{word:08x}\n" for word in words), encoding="ascii")
        if args.listing:
            args.listing.parent.mkdir(parents=True, exist_ok=True)
            args.listing.write_text("\n".join(listing_lines) + "\n", encoding="utf-8")

        print(f"ASSEMBLY_PASS input={args.input} output={args.output} words={len(words)}")
        return 0
    except (OSError, ValueError) as exc:
        print(f"ASSEMBLY_ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
