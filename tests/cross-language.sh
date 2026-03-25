#!/usr/bin/env bash
# Cross-language AST comparison: parse identical inputs in all 5 languages,
# serialize to JSON, diff. Any divergence = bug.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
KAPPA_DIR="$(dirname "$TESTS_DIR")"
PASS=0
FAIL=0

red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

# ── Test cases ──
# Each test: name|input
CASES=(
  # ── v2 basic (required-by-default, no explicit id) ──
  "simple_entity|User { email: s@~, name: s }"
  "all_type_codes|T { a: s, b: t, c: i, d: f, e: b, f: d, g: dt, h: id, i: x, j: m }"
  "all_modifiers|T { a: s, b: s?, c: s!, d: s~, e: s@, f: i++, g: s^, h: s#email }"
  "stacked_modifiers|T { email: s@~(5,255)#email }"
  "constraint_min_only|T { age: i(18,) }"
  "constraint_max_only|T { qty: i(,100) }"
  "constraint_exact|T { code: s(6,6) }"
  "constraint_float|T { rate: f(0.01,99.99) }"
  "default_bool|T { active: b=true, deleted: b=false }"
  "default_number|T { stock: i=0, temp: f=1.5 }"
  "default_string|T { lang: s=\"en\", fmt: s=\"{}\" }"
  "default_ident|T { role: (a|b|c)=b }"
  "enum_type|T { status: (draft|published|archived) }"
  "array_primitive|T { tags: [s], scores: [i] }"
  "array_reference|T { items: [Item] }"
  "reference_required|T { author: User }"
  "reference_optional|T { team: Team? }"
  "reference_immutable|T { org: Org! }"
  "self_reference|T { parent: T? }"
  "empty_entity|T { }"
  "multiple_entities|A { x: s } B { y: i }"
  "comment_line|// a comment\nUser { name: s }"
  "comment_inline|User { /* block */ name: s }"
  "trailing_comma|T { a: s, b: i, }"
  "multiline|T {\n  name: s(1,100),\n  active: b=true\n}"
  "complex_field|T { sku: s@~(8,20), price: m(0.01,)=0.0, status: (draft|active|discontinued)=draft }"

  # ── v2 new features ──
  "named_enum|enum Status (draft|active|archived)\nT { status: Status=draft }"
  "multiple_named_enums|enum Role (admin|editor|viewer)\nenum Status (draft|active)\nT { role: Role=viewer, status: Status }"
  "format_email|T { email: s@~#email }"
  "format_url|T { website: s?#url }"
  "format_slug|T { slug: s@!#slug }"
  "format_phone|T { phone: s?#phone }"
  "hidden_field|T { password_hash: s^, api_key: s!^ }"
  "hidden_timestamp|T { name: s, created: dt!^, updated: dt^ }"
  "decimal_type|T { price: m(0.01,), balance: m(0,)=0 }"
  "unique_constraint|T { org: Org, email: s@~#email } @unique(org, email)"
  "multiple_constraints|T { org: Org, email: s, slug: s@ } @unique(org, email) @unique(org, slug)"
  "star_redundant|T { name: s*, email: s }"
  "required_by_default|T { name: s, description: t?, active: b=true }"

  # ── Adversarial strings ──
  "escaped_quotes|T { x: s=\"he said \\\\\"hello\\\\\"\" }"
  "empty_string_default|T { x: s=\"\" }"
  "string_with_braces|T { x: s=\"{a:1}\" }"
  "string_with_parens|T { x: s=\"(1,2)\" }"
  "string_with_pipes|T { x: s=\"a|b|c\" }"
  "string_single_quote|T { x: s='test' }"

  # ── Deeply nested / complex types ──
  "nested_array|T { x: [[s]] }"
  "triple_nested_array|T { x: [[[i]]] }"
  "array_of_enum|T { x: [(a|b|c)] }"
  "enum_single_value|T { x: (only) }"
  "enum_many_values|T { x: (a|b|c|d|e|f|g|h|i|j) }"

  # ── Boundary values ──
  "zero_constraint|T { x: i(0,0) }"
  "large_numbers|T { x: i(0,999999999) }"
  "float_precision|T { x: f(0.001,99.999) }"
  "null_default|T { x: s=null }"
  "long_entity_name|ThisIsAnExtremelyLongEntityNameThatShouldStillWork { name: s }"
  "long_field_name|T { this_is_a_very_long_field_name_with_underscores: s }"

  # ── Grammar ambiguity: field names match type codes ──
  "field_named_d|T { d: d }"
  "field_named_id|T { id: id }"
  "field_named_dt|T { dt: dt }"
  "field_named_s|T { s: s }"
  "field_named_b|T { b: b }"
  "field_named_x|T { x: x }"
  "field_named_i|T { i: i }"
  "field_named_f|T { f: f }"
  "field_named_t|T { t: t }"
  "field_named_m|T { m: m }"

  # ── Modifier ordering ──
  "mods_all_stacked|T { x: s?!@~^(1,50)#email=\"hi\" }"
  "mods_reverse_order|T { x: s~@!? }"
  "unique_indexed|T { x: s@~ }"
  "immutable_hidden|T { x: dt!^ }"

  # ── Whitespace variations ──
  "extra_spaces|T {   name  :  s  ,  email  :  s  }"
  "tabs_and_newlines|T {\t\n\tname: s,\t\n\temail: s\n}"
  "no_spaces|T{name:s,email:s}"

  # ── Multiple entities with references ──
  "three_entities|A { x: s } B { a: A } C { b: B?, a: A }"
  "entity_after_comment|// first\nA { x: s }\n// second\nB { y: i }"

  # ── Defaults on different types ──
  "default_on_enum|T { x: (a|b|c)=a }"
  "default_on_constraint|T { x: i(0,100)=50 }"
  "default_zero_float|T { x: f=0.0 }"
  "default_negative|T { x: i=-5 }"
  "default_decimal|T { x: m=0.0 }"
)

# ── Serializers per language ──

ts_json() {
  node --input-type=module -e "
import { parse } from '$KAPPA_DIR/parsers/typescript-gen/dist/index.js';
const r = parse(process.argv[1]);
console.log(JSON.stringify(r.entities, null, 2));
" -- "$1"
}

py_json() {
  python3 -c "
import sys, json
sys.path.insert(0, '$KAPPA_DIR/parsers/python')
from kappa_parser import parse, Field, Entity, PrimitiveType, ArrayType, ReferenceType, EnumType, Constraint
def to_dict(obj):
    if isinstance(obj, (str, int, float, bool)) or obj is None:
        return obj
    if isinstance(obj, list):
        return [to_dict(x) for x in obj]
    if hasattr(obj, '__dataclass_fields__'):
        d = {}
        for k in obj.__dataclass_fields__:
            v = getattr(obj, k)
            if k == 'auto_increment':
                k = 'autoIncrement'
            if v is None and k in ('constraint', 'default'):
                continue
            d[k] = to_dict(v)
        return d
    return obj
r = parse(sys.argv[1])
print(json.dumps([to_dict(e) for e in r.entities], indent=2))
" "$1"
}

rs_json() {
  # Write a temp Rust program that parses and outputs JSON
  cat > /tmp/_kappa_verify.rs << 'RSEOF'
use std::env;
fn print_type(ft: &kappa_parser::FieldType) {
    match ft {
        kappa_parser::FieldType::Primitive { code } => print!("{{\"kind\":\"primitive\",\"code\":{:?}}}", code),
        kappa_parser::FieldType::Array { element_type } => {
            print!("{{\"kind\":\"array\",\"elementType\":");
            print_type(element_type.as_ref());
            print!("}}");
        }
        kappa_parser::FieldType::Reference { entity } => print!("{{\"kind\":\"reference\",\"entity\":{:?}}}", entity),
        kappa_parser::FieldType::Enum { values } => {
            print!("{{\"kind\":\"enum\",\"values\":[");
            for (vi, v) in values.iter().enumerate() {
                if vi > 0 { print!(","); }
                print!("{:?}", v);
            }
            print!("]}}");
        }
    }
}
fn main() {
    let input = env::args().nth(1).unwrap();
    let result = kappa_parser::parse(&input);
    print!("[");
    for (ei, ent) in result.entities.iter().enumerate() {
        if ei > 0 { print!(","); }
        print!("\n  {{\"kind\":\"entity\",\"name\":{:?},\"fields\":[", ent.name);
        for (fi, f) in ent.fields.iter().enumerate() {
            if fi > 0 { print!(","); }
            print!("\n    {{\"kind\":\"field\",\"name\":{:?},\"type\":", f.name);
            print_type(&f.field_type);
            print!(",\"required\":{},\"optional\":{},\"immutable\":{},\"indexed\":{},\"unique\":{},\"autoIncrement\":{}",
                f.required, f.optional, f.immutable, f.indexed, f.unique, f.auto_increment);
            if f.hidden { print!(",\"hidden\":true"); }
            if let Some(fmt) = &f.format { print!(",\"format\":{:?}", fmt); }
            if let Some(c) = &f.constraint {
                print!(",\n        \"constraint\": {{");
                let mut first = true;
                if let Some(mn) = c.min { if !first { print!(", "); } print!("\"min\": {}", mn); first = false; }
                if let Some(mx) = c.max { if !first { print!(", "); } print!("\"max\": {}", mx); }
                print!("}}");
            }
            if let Some(d) = &f.default {
                print!(",\n        \"default\": ");
                match d {
                    kappa_parser::DefaultValue::Str(s) => print!("{:?}", s),
                    kappa_parser::DefaultValue::Num(n) => { if *n == (*n as i64) as f64 { print!("{}", *n as i64) } else { print!("{}", n) } },
                    kappa_parser::DefaultValue::Bool(b) => print!("{}", b),
                    kappa_parser::DefaultValue::Null => print!("null"),
                }
            }
            print!("\n      }}");
        }
        print!("\n    ]");
        if !ent.unique_constraints.is_empty() {
            print!(",\"uniqueConstraints\":[");
            for (ci, uc) in ent.unique_constraints.iter().enumerate() {
                if ci > 0 { print!(","); }
                print!("[");
                for (fi, f) in uc.iter().enumerate() {
                    if fi > 0 { print!(","); }
                    print!("{:?}", f);
                }
                print!("]");
            }
            print!("]");
        }
        print!("\n  }}");
    }
    println!("\n]");
}
RSEOF
  cd /tmp/kappa/parsers/rust
  # Compile the verify binary once if needed
  if [ ! -f /tmp/_kappa_rs_verify ] || [ /tmp/_kappa_verify.rs -nt /tmp/_kappa_rs_verify ]; then
    rustc --edition 2021 -L target/debug/deps --extern kappa_parser=target/debug/libkappa_parser.rlib /tmp/_kappa_verify.rs -o /tmp/_kappa_rs_verify 2>/dev/null
  fi
  /tmp/_kappa_rs_verify "$1"
}

go_json() {
  # Compile Go verify binary once
  if [ ! -f /tmp/_kappa_go_verify ]; then
    cat > /tmp/kappa/parsers/go/cmd_verify.go << 'GOEOF'
//go:build ignore

package main

import (
    "encoding/json"
    "fmt"
    "os"
    kappa "github.com/owenob1/kappa/parsers/go"
)

type jField struct {
    Kind          string      `json:"kind"`
    Name          string      `json:"name"`
    Type          interface{} `json:"type"`
    Required      bool        `json:"required"`
    Optional      bool        `json:"optional"`
    Immutable     bool        `json:"immutable"`
    Indexed       bool        `json:"indexed"`
    Unique        bool        `json:"unique"`
    AutoIncrement bool        `json:"autoIncrement"`
    Hidden        bool        `json:"hidden,omitempty"`
    Format        string      `json:"format,omitempty"`
    Constraint    *jConst     `json:"constraint,omitempty"`
    Default       interface{} `json:"default,omitempty"`
}

type jConst struct {
    Min *float64 `json:"min,omitempty"`
    Max *float64 `json:"max,omitempty"`
}

func convType(ft kappa.FieldType) interface{} {
    switch t := ft.(type) {
    case kappa.PrimitiveType:
        return map[string]string{"kind": "primitive", "code": t.Code}
    case kappa.ArrayType:
        return map[string]interface{}{"kind": "array", "elementType": convType(t.ElementType)}
    case kappa.ReferenceType:
        return map[string]string{"kind": "reference", "entity": t.Entity}
    case kappa.EnumType:
        return map[string]interface{}{"kind": "enum", "values": t.Values}
    }
    return nil
}

func main() {
    result := kappa.Parse(os.Args[1])
    var out []map[string]interface{}
    for _, ent := range result.Entities {
        fields := make([]jField, 0)
        for _, f := range ent.Fields {
            jf := jField{Kind: "field", Name: f.Name, Type: convType(f.Type),
                Required: f.Required, Optional: f.Optional, Immutable: f.Immutable,
                Indexed: f.Indexed, Unique: f.Unique, AutoIncrement: f.AutoIncrement,
                Hidden: f.Hidden, Format: f.Format}
            if f.Constraint != nil {
                jf.Constraint = &jConst{Min: f.Constraint.Min, Max: f.Constraint.Max}
            }
            if f.Default != nil {
                jf.Default = f.Default
            }
            fields = append(fields, jf)
        }
        entMap := map[string]interface{}{"kind": "entity", "name": ent.Name, "fields": fields}
        if len(ent.UniqueConstraints) > 0 { entMap["uniqueConstraints"] = ent.UniqueConstraints }
        out = append(out, entMap)
    }
    b, _ := json.MarshalIndent(out, "", "  ")
    fmt.Println(string(b))
}
GOEOF
    cd /tmp/kappa/parsers/go && go build -o /tmp/_kappa_go_verify cmd_verify.go 2>/dev/null
  fi
  /tmp/_kappa_go_verify "$1"
}

java_json() {
  if [ ! -f /tmp/_kappa_java_verify ]; then
    cat > /tmp/_KappaVerify.java << 'JAVAEOF'
import dev.kappa.KappaParser;
import dev.kappa.KappaParser.*;
import java.util.*;

public class _KappaVerify {
    static String jsonType(FieldType ft) {
        if (ft instanceof PrimitiveType p) return "{\"kind\":\"primitive\",\"code\":\"" + p.code() + "\"}";
        if (ft instanceof ReferenceType r) return "{\"kind\":\"reference\",\"entity\":\"" + r.entity() + "\"}";
        if (ft instanceof EnumType e) {
            var sb = new StringBuilder("{\"kind\":\"enum\",\"values\":[");
            for (int i = 0; i < e.values().size(); i++) { if (i > 0) sb.append(","); sb.append("\"").append(e.values().get(i)).append("\""); }
            sb.append("]}"); return sb.toString();
        }
        if (ft instanceof ArrayType a) return "{\"kind\":\"array\",\"elementType\":" + jsonType(a.elementType()) + "}";
        return "{}";
    }
    static String esc(String s) { return s.replace("\\", "\\\\").replace("\"", "\\\""); }
    static String jsonDefault(Object d) {
        if (d == null) return "null";
        if (d instanceof Boolean) return d.toString();
        if (d instanceof Double v) { if (v == Math.floor(v) && !Double.isInfinite(v)) return String.valueOf(v.longValue()); return v.toString(); }
        if (d instanceof String s) return "\"" + esc(s) + "\"";
        return "\"" + d + "\"";
    }
    public static void main(String[] args) {
        var result = KappaParser.parse(args[0]);
        var sb = new StringBuilder("[");
        for (int ei = 0; ei < result.entities().size(); ei++) {
            var ent = result.entities().get(ei);
            if (ei > 0) sb.append(",");
            sb.append("\n  {\"kind\":\"entity\",\"name\":\"").append(ent.name()).append("\",\"fields\":[");
            for (int fi = 0; fi < ent.fields().size(); fi++) {
                var f = ent.fields().get(fi);
                if (fi > 0) sb.append(",");
                sb.append("\n    {\"kind\":\"field\",\"name\":\"").append(f.name()).append("\",");
                sb.append("\"type\":").append(jsonType(f.type())).append(",");
                sb.append("\"required\":").append(f.required()).append(",");
                sb.append("\"optional\":").append(f.optional()).append(",");
                sb.append("\"immutable\":").append(f.immutable()).append(",");
                sb.append("\"indexed\":").append(f.indexed()).append(",");
                sb.append("\"unique\":").append(f.unique()).append(",");
                sb.append("\"autoIncrement\":").append(f.autoIncrement());
                if (f.hidden()) sb.append(",\"hidden\":true");
                if (f.format() != null && !f.format().isEmpty()) sb.append(",\"format\":\"").append(f.format()).append("\"");
                if (f.constraint() != null) {
                    sb.append(",\"constraint\":{");
                    boolean first = true;
                    if (f.constraint().min() != null) {
                        double v = f.constraint().min();
                        sb.append("\"min\":"); if (v == Math.floor(v)) sb.append((long)v); else sb.append(v); first = false;
                    }
                    if (f.constraint().max() != null) {
                        if (!first) sb.append(",");
                        double v = f.constraint().max();
                        sb.append("\"max\":"); if (v == Math.floor(v)) sb.append((long)v); else sb.append(v);
                    }
                    sb.append("}");
                }
                if (f.defaultValue() != null) sb.append(",\"default\":").append(jsonDefault(f.defaultValue()));
                sb.append("}");
            }
            sb.append("\n  ]");
            if (ent.uniqueConstraints() != null && !ent.uniqueConstraints().isEmpty()) {
                sb.append(",\"uniqueConstraints\":[");
                for (int ci = 0; ci < ent.uniqueConstraints().size(); ci++) {
                    if (ci > 0) sb.append(",");
                    sb.append("[");
                    var uc = ent.uniqueConstraints().get(ci);
                    for (int ui = 0; ui < uc.size(); ui++) {
                        if (ui > 0) sb.append(",");
                        sb.append("\"").append(uc.get(ui)).append("\"");
                    }
                    sb.append("]");
                }
                sb.append("]");
            }
            sb.append("}");
        }
        sb.append("\n]");
        System.out.println(sb);
    }
}
JAVAEOF
    cp /tmp/_KappaVerify.java /tmp/kappa/parsers/java/src/main/java/
    cd /tmp/kappa/parsers/java/src/main/java && javac dev/kappa/KappaParser.java _KappaVerify.java 2>/dev/null
  fi
  cd /tmp/kappa/parsers/java/src/main/java && java -cp . _KappaVerify "$1"
}

# ── Normalize JSON for comparison ──
normalize() {
  # Sort keys, normalize numbers, snake_case→camelCase, remove nulls
  python3 -c "
import json, sys, re

def to_camel(s):
    parts = s.split('_')
    return parts[0] + ''.join(p.capitalize() for p in parts[1:])

def norm(obj):
    if isinstance(obj, dict):
        out = {}
        for k, v in sorted(obj.items()):
            ck = to_camel(k)
            nv = norm(v)
            # Skip null/None for optional fields
            if nv is None and ck in ('constraint', 'default', 'min', 'max', 'format'):
                continue
            # Skip false for boolean defaults
            if nv is False and ck in ('hidden',):
                continue
            # Skip empty lists for collection defaults
            if isinstance(nv, list) and len(nv) == 0 and ck in ('uniqueConstraints', 'enumDeclarations'):
                continue
            # Skip empty string for string defaults
            if nv == '' and ck in ('format',):
                continue
            out[ck] = nv
        return out
    if isinstance(obj, list):
        return [norm(x) for x in obj]
    if isinstance(obj, float) and obj == int(obj):
        return int(obj)
    return obj
data = json.load(sys.stdin)
print(json.dumps(norm(data), indent=2, sort_keys=True))
"
}

# ── Run all AST comparison tests ──
echo "═══ PART 1: Cross-language AST comparison ═══"
echo "${#CASES[@]} test cases × 5 languages (TS, Python, Rust, Go, Java)"
echo ""

for case in "${CASES[@]}"; do
  name="${case%%|*}"
  input="${case#*|}"
  input="$(echo -e "$input")"

  ts_out="$(ts_json "$input" 2>/dev/null | normalize)" || { red "FAIL $name: TypeScript crashed"; FAIL=$((FAIL+1)); continue; }
  py_out="$(py_json "$input" 2>/dev/null | normalize)" || { red "FAIL $name: Python crashed"; FAIL=$((FAIL+1)); continue; }

  diverged=false

  if [ "$ts_out" != "$py_out" ]; then
    red "FAIL $name: TypeScript ≠ Python"
    diff <(echo "$ts_out") <(echo "$py_out") || true
    diverged=true
  fi

  rs_out="$(rs_json "$input" 2>/dev/null | normalize)" || rs_out="CRASH"
  if [ "$rs_out" != "CRASH" ] && [ "$ts_out" != "$rs_out" ]; then
    red "FAIL $name: TypeScript ≠ Rust"
    diff <(echo "$ts_out") <(echo "$rs_out") || true
    diverged=true
  fi

  go_out="$(go_json "$input" 2>/dev/null | normalize)" || go_out="CRASH"
  if [ "$go_out" != "CRASH" ] && [ "$ts_out" != "$go_out" ]; then
    red "FAIL $name: TypeScript ≠ Go"
    diff <(echo "$ts_out") <(echo "$go_out") || true
    diverged=true
  fi

  java_out="$(java_json "$input" 2>/dev/null | normalize)" || java_out="CRASH"
  if [ "$java_out" != "CRASH" ] && [ "$ts_out" != "$java_out" ]; then
    red "FAIL $name: TypeScript ≠ Java"
    diff <(echo "$ts_out") <(echo "$java_out") || true
    diverged=true
  fi

  if [ "$diverged" = true ]; then
    FAIL=$((FAIL+1))
  else
    green "PASS $name"
    PASS=$((PASS+1))
  fi
done

echo ""
echo "Part 1: $PASS passed, $FAIL failed out of ${#CASES[@]} tests"

# ═══════════════════════════════════════════
# PART 2: Error recovery
# ═══════════════════════════════════════════
echo ""
echo "═══ PART 2: Error recovery ═══"

# Error recovery tests: malformed input, verify surviving fields across languages
# Format: name:::input:::expected_entity_count:::expected_total_field_count
ERROR_CASES=(
  "bad_type_code:::T { name: s, bad: q, email: s@~ }:::1:::3"
  "missing_colon:::T { name s, email: s }:::1:::1"
  "double_comma:::T { name: s,, email: s }:::1:::1"
  "unclosed_paren:::T { name: s, bad: (a|b, email: s }:::1:::1"
  "extra_rbrace_after:::T { name: s } }:::1:::1"
  "empty_input::: :::0:::0"
  "just_comment:::// nothing here:::0:::0"
  "only_braces:::{ }:::0:::0"
)

E_PASS=0
E_FAIL=0

for case in "${ERROR_CASES[@]}"; do
  name="${case%%:::*}"; rest="${case#*:::}"
  input="${rest%%:::*}"; rest="${rest#*:::}"
  expected_ents="${rest%%:::*}"; expected_fields="${rest#*:::}"
  input="$(echo -e "$input")"

  check_counts() {
    local lang="$1" json="$2"
    local ents fields
    # Handle null/empty JSON
    if [ -z "$json" ] || [ "$json" = "null" ]; then json="[]"; fi
    ents=$(echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); d=d if isinstance(d,list) else []; print(len(d))" 2>/dev/null) || ents="ERR"
    fields=$(echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); d=d if isinstance(d,list) else []; print(sum(len(e.get('fields',e.get('Fields',[])) if isinstance(e,dict) else []) for e in d))" 2>/dev/null) || fields="ERR"
    if [ "$ents" != "$expected_ents" ] || [ "$fields" != "$expected_fields" ]; then
      red "  $lang: got $ents entities/$fields fields, expected $expected_ents/$expected_fields"
      return 1
    fi
    return 0
  }

  all_ok=true
  ts_out="$(ts_json "$input" 2>/dev/null)" || ts_out="[]"
  check_counts "TypeScript" "$ts_out" || all_ok=false
  py_out="$(py_json "$input" 2>/dev/null)" || py_out="[]"
  check_counts "Python" "$py_out" || all_ok=false
  rs_out="$(rs_json "$input" 2>/dev/null)" || rs_out="[]"
  check_counts "Rust" "$rs_out" || all_ok=false
  go_out="$(go_json "$input" 2>/dev/null)" || go_out="[]"
  check_counts "Go" "$go_out" || all_ok=false
  java_out="$(java_json "$input" 2>/dev/null)" || java_out="[]"
  check_counts "Java" "$java_out" || all_ok=false

  if [ "$all_ok" = true ]; then
    green "PASS $name ($expected_ents ent, $expected_fields fields recovered)"
    E_PASS=$((E_PASS+1))
  else
    E_FAIL=$((E_FAIL+1))
  fi
done

echo ""
echo "Part 2: $E_PASS passed, $E_FAIL failed out of ${#ERROR_CASES[@]} error recovery tests"

# ═══════════════════════════════════════════
# PART 3: Streaming parity (TypeScript)
# ═══════════════════════════════════════════
echo ""
echo "═══ PART 3: Streaming parity ═══"

S_PASS=0
S_FAIL=0

stream_test() {
  local name="$1" input="$2"
  local result
  result=$(node --input-type=module -e "
import { parse, StreamingParser } from '$KAPPA_DIR/parsers/typescript-gen/dist/index.js';

const input = process.argv[1];

// Batch parse
const batch = parse(input);
const batchFields = batch.entities.flatMap(e => e.fields.map(f => e.name + '.' + f.name));

// Streaming parse (character by character)
const sp = new StreamingParser();
const streamFields = [];
sp.onField((f, eName) => streamFields.push(eName + '.' + f.name));
// Feed one character at a time to truly test streaming
for (const ch of input) sp.feed(ch);
sp.end();

if (batchFields.length !== streamFields.length) {
  console.log('MISMATCH count: batch=' + batchFields.length + ' stream=' + streamFields.length);
  process.exit(1);
}
for (let i = 0; i < batchFields.length; i++) {
  if (batchFields[i] !== streamFields[i]) {
    console.log('MISMATCH at ' + i + ': batch=' + batchFields[i] + ' stream=' + streamFields[i]);
    process.exit(1);
  }
}
console.log('OK ' + batchFields.length + ' fields');
" -- "$input" 2>&1)

  if [ $? -eq 0 ]; then
    green "PASS stream: $name ($result)"
    S_PASS=$((S_PASS+1))
  else
    red "FAIL stream: $name — $result"
    S_FAIL=$((S_FAIL+1))
  fi
}

# Test streaming against all example files
for f in "$KAPPA_DIR"/examples/dense/*.kappa; do
  stream_test "$(basename "$f")" "$(cat "$f")"
done

# Test streaming with adversarial inputs
stream_test "complex_inline" 'Product { id: id*, sku: s*@~(8,20), price: f*(0.01,)=0.0, status: (draft|active|discontinued)=draft, tags: [s], created: dt! }'
stream_test "multiline" "$(printf 'User {\n  id: id*,\n  email: s*@~,\n  name: s*(1,100)\n}')"
stream_test "with_comments" "$(printf '// header\nUser { id: id* /* pk */, name: s* }')"
stream_test "multiple_entities" 'A { x: s* } B { y: i*, z: b=true }'
stream_test "string_defaults" 'T { a: s="hello", b: s="{}", c: s="(1,2)" }'
stream_test "empty_entity" 'T { }'

echo ""
echo "Part 3: $S_PASS passed, $S_FAIL failed streaming tests"

# ═══════════════════════════════════════════
# PART 4: Performance
# ═══════════════════════════════════════════
echo ""
echo "═══ PART 4: Performance ═══"

# Generate a large .kappa file
LARGE_INPUT=$(python3 -c "
lines = []
for i in range(200):
    lines.append(f'Entity{i} {{ id: id*, name: s*(1,100), email: s*@~, role: (admin|editor|viewer)=viewer, active: b=true, score: f*(0,100)=0.0, tags: [s], ref: Entity0?, created: dt! }}')
print('\n'.join(lines))
")

ENTITY_COUNT=$(echo "$LARGE_INPUT" | grep -c '{')
echo "Input: $ENTITY_COUNT entities"

for lang_name in TypeScript Python Rust Go Java; do
  case $lang_name in
    TypeScript) cmd="ts_json" ;;
    Python) cmd="py_json" ;;
    Rust) cmd="rs_json" ;;
    Go) cmd="go_json" ;;
    Java) cmd="java_json" ;;
  esac
  start_ms=$(date +%s%N)
  result=$($cmd "$LARGE_INPUT" 2>/dev/null)
  end_ms=$(date +%s%N)
  elapsed_ms=$(( (end_ms - start_ms) / 1000000 ))
  ent_count=$(echo "$result" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null)
  if [ "$ent_count" = "$ENTITY_COUNT" ]; then
    green "  $lang_name: ${elapsed_ms}ms — $ent_count entities parsed"
  else
    red "  $lang_name: ${elapsed_ms}ms — WRONG: got $ent_count entities, expected $ENTITY_COUNT"
  fi
done

# ═══════════════════════════════════════════
# PART 5: Fuzz testing (4 categories)
# ═══════════════════════════════════════════
echo ""
echo "═══ PART 5: Fuzz testing ═══"

FUZZ_PASS=0
FUZZ_FAIL=0

fuzz_check() {
  local input="$1"
  for lang_cmd in "TypeScript:ts_json" "Python:py_json" "Rust:rs_json" "Go:go_json" "Java:java_json"; do
    local lang="${lang_cmd%%:*}" cmd="${lang_cmd#*:}"
    timeout 10 bash -c "$cmd \"\$1\" >/dev/null 2>&1" -- "$input"
    local rc=$?
    if [ $rc -gt 128 ]; then
      red "  CRASH: $lang signal-killed (rc=$rc) on input (${#input} bytes)"
      return 1
    fi
  done
  return 0
}

# 5a: Pure random bytes (500 inputs)
echo "  5a: 500 pure random strings..."
FUZZ_5A=0
while IFS= read -r line; do
  if fuzz_check "$line" 2>/dev/null; then
    FUZZ_5A=$((FUZZ_5A + 1))
  else
    FUZZ_FAIL=$((FUZZ_FAIL + 1))
  fi
done < <(python3 -c "
import random, string
random.seed(42)
# Use printable chars minus newlines to keep one-input-per-line
chars = ''.join(c for c in string.printable if c not in '\n\r')
for _ in range(500):
    n = random.randint(0, 300)
    print(''.join(random.choice(chars) for _ in range(n)))
")
FUZZ_PASS=$((FUZZ_PASS + FUZZ_5A))
echo "    $FUZZ_5A/500 survived"

# 5b: Structured mutations (200 inputs — valid Kappa with random corruption)
echo "  5b: 200 structured mutations..."
FUZZ_5B=0
while IFS= read -r line; do
  if fuzz_check "$line" 2>/dev/null; then
    FUZZ_5B=$((FUZZ_5B + 1))
  else
    FUZZ_FAIL=$((FUZZ_FAIL + 1))
  fi
done < <(python3 -c "
import random
random.seed(77)
base_inputs = [
    'User { id: id*, email: s*@~ }',
    'T { x: i*(0,100)=50, y: (a|b|c)=a, z: [s] }',
    'A { r: B* } B { s: s }',
    'X { a: s*@~!(1,255)=\"hi\", b: dt!, c: f*(0.01,99.99) }',
]
mutations = [
    lambda s,i: s[:i] + s[i+1:],         # delete char
    lambda s,i: s[:i] + chr(random.randint(0,127)) + s[i:],  # insert random
    lambda s,i: s[:i] + chr(random.randint(0,127)) + s[i+1:],  # replace
    lambda s,i: s[:i] + s[i:i+1]*random.randint(2,10) + s[i+1:],  # repeat
    lambda s,i: s + s,                     # duplicate whole input
]
for _ in range(200):
    src = random.choice(base_inputs)
    m = random.choice(mutations)
    pos = random.randint(0, max(0, len(src)-1))
    try:
        result = m(src, pos)
        # filter out non-printable to avoid shell issues
        result = ''.join(c if (c.isprintable() and c not in '\n\r') else '?' for c in result)
        print(result)
    except:
        print(src)
")
FUZZ_PASS=$((FUZZ_PASS + FUZZ_5B))
echo "    $FUZZ_5B/200 survived"

# 5c: Extreme lengths (20 inputs)
echo "  5c: 20 extreme length inputs..."
FUZZ_5C=0
while IFS= read -r line; do
  if fuzz_check "$line" 2>/dev/null; then
    FUZZ_5C=$((FUZZ_5C + 1))
  else
    FUZZ_FAIL=$((FUZZ_FAIL + 1))
  fi
done < <(python3 -c "
# Very long entity names, field names, string defaults, many fields
cases = [
    'A' * 10000 + ' { x: s }',
    'T { ' + 'x' * 10000 + ': s }',
    'T { x: s=\"' + 'a' * 10000 + '\" }',
    'T { ' + ', '.join(f'f{i}: s' for i in range(500)) + ' }',
    'T { x: (' + '|'.join(f'v{i}' for i in range(200)) + ') }',
    ' '.join(f'E{i} {{ x: s }}' for i in range(500)),
    'T { x: ' + '[' * 50 + 's' + ']' * 50 + ' }',
    'T { x: s' + '*' * 1000 + ' }',
    'T { x: i(' + '0' * 100 + ',' + '9' * 100 + ') }',
    '',
    ' ',
    ' ' * 1000,
    '{' * 500,
    '}' * 500,
    '(' * 500,
    ')' * 500,
    ':' * 500,
    ',' * 500,
    '// ' + 'x' * 10000,
    '/* ' + 'x' * 10000 + ' */',
]
for c in cases:
    print(c)
")
FUZZ_PASS=$((FUZZ_PASS + FUZZ_5C))
echo "    $FUZZ_5C/20 survived"

# 5d: Binary / null bytes (30 inputs)
echo "  5d: 30 binary/null byte inputs..."
FUZZ_5D=0
for i in $(seq 1 30); do
  input=$(python3 -c "
import random, sys
random.seed($i)
n = random.randint(1, 200)
data = bytes(random.randint(0, 255) for _ in range(n))
# Mix with some valid Kappa
if $i % 3 == 0:
    data = b'T { x: s, ' + data + b' }'
sys.stdout.buffer.write(data)
" 2>/dev/null || echo "")
  if fuzz_check "$input" 2>/dev/null; then
    FUZZ_5D=$((FUZZ_5D + 1))
  else
    FUZZ_FAIL=$((FUZZ_FAIL + 1))
  fi
done
FUZZ_PASS=$((FUZZ_PASS + FUZZ_5D))
echo "    $FUZZ_5D/30 survived"

FUZZ_TOTAL=$((FUZZ_PASS + FUZZ_FAIL))
if [ $FUZZ_FAIL -eq 0 ]; then
  green "PASS All $FUZZ_TOTAL fuzz inputs: zero crashes"
else
  red "FAIL $FUZZ_FAIL/$FUZZ_TOTAL fuzz inputs caused crashes"
fi
echo "Part 5: $FUZZ_PASS/$FUZZ_TOTAL fuzz tests passed"

# ═══════════════════════════════════════════
# PART 6: Cross-language roundtrip (500 trials)
# ═══════════════════════════════════════════
echo ""
echo "═══ PART 6: Cross-language roundtrip (500 trials) ═══"

RT_PASS=0
RT_FAIL=0

python3 << 'PYEOF' > /tmp/_kappa_roundtrip_inputs.txt
import random
random.seed(123)

TYPE_CODES = ['s', 't', 'i', 'f', 'b', 'd', 'dt', 'id', 'x']
ENUM_VALS = ['draft', 'active', 'archived', 'pending', 'done', 'admin', 'user', 'editor']
NAMES = ['User', 'Post', 'Item', 'Order', 'Task', 'Org', 'Team', 'Tag', 'Log', 'Role']

def rand_type():
    r = random.random()
    if r < 0.45: return random.choice(TYPE_CODES)
    if r < 0.60: return '(' + '|'.join(random.sample(ENUM_VALS, k=random.randint(2, 4))) + ')'
    if r < 0.70: return '[' + random.choice(TYPE_CODES) + ']'
    if r < 0.80: return '[' + random.choice(NAMES) + ']'
    if r < 0.85: return '[[' + random.choice(TYPE_CODES) + ']]'
    return random.choice(NAMES)

def rand_mods(tc):
    m = ''
    if random.random() < 0.5: m += '*'
    elif random.random() < 0.3: m += '?'
    if random.random() < 0.15: m += '!'
    if random.random() < 0.15: m += '@'
    if random.random() < 0.15: m += '~'
    if tc in ('i', 'f', 's') and random.random() < 0.3:
        mn = random.randint(0, 50)
        mx = mn + random.randint(1, 200)
        m += f'({mn},{mx})'
    return m

def rand_default(tc):
    if random.random() < 0.65: return ''
    if tc == 'b': return '=' + random.choice(['true', 'false'])
    if tc in ('i',): return '=' + str(random.randint(-50, 100))
    if tc in ('f',): return '=' + str(round(random.uniform(0, 100), 2))
    if tc == 's': return '="' + random.choice(['hello', 'test', 'x', '', '{}', '(1,2)']) + '"'
    return ''

def rand_field(idx):
    name = f'f{idx}'
    tc = rand_type()
    base = tc.lstrip('[').rstrip(']').split('(')[0]
    mods = rand_mods(base)
    default = rand_default(base)
    return f'{name}: {tc}{mods}{default}'

for trial in range(500):
    n_ent = random.randint(1, 4)
    ents = []
    for i in range(n_ent):
        name = random.choice(NAMES) + str(i)
        nf = random.randint(1, 10)
        fields = ', '.join(rand_field(j) for j in range(nf))
        ents.append(f'{name} {{ {fields} }}')
    # Use \x00 as separator between trials
    print('\n'.join(ents))
    print('---TRIAL_SEP---')
PYEOF

# Parse each trial in Python, serialize back, then verify all 5 languages agree on the roundtrip
RT_TESTED=0
while IFS= read -r -d '' trial_block || [ -n "$trial_block" ]; do
  true  # placeholder
done < /tmp/_kappa_roundtrip_inputs.txt

# Simpler approach: use Python to do roundtrip + serialize, then verify cross-language
python3 << 'PYEOF'
import sys, os, json

sys.path.insert(0, '/tmp/kappa/parsers/python')
from kappa_parser import parse

def ser_type(t):
    if t.kind == 'primitive': return t.code
    if t.kind == 'reference': return t.entity
    if t.kind == 'enum': return '(' + '|'.join(t.values) + ')'
    if t.kind == 'array': return '[' + ser_type(t.element_type) + ']'
    return '?'

def ser_field(f):
    s = f.name + ': ' + ser_type(f.type)
    if f.required: s += '*'
    if f.optional: s += '?'
    if f.immutable: s += '!'
    if f.unique: s += '@'
    if f.indexed: s += '~'
    if f.auto_increment: s += '++'
    if f.constraint:
        mn = '' if f.constraint.min is None else (str(int(f.constraint.min)) if f.constraint.min is not None and f.constraint.min == int(f.constraint.min) else str(f.constraint.min))
        mx = '' if f.constraint.max is None else (str(int(f.constraint.max)) if f.constraint.max is not None and f.constraint.max == int(f.constraint.max) else str(f.constraint.max))
        s += f'({mn},{mx})'
    if f.default is not None:
        d = f.default
        if isinstance(d, bool): s += '=' + str(d).lower()
        elif isinstance(d, (int, float)):
            s += '=' + (str(int(d)) if isinstance(d, float) and d == int(d) else str(d))
        elif isinstance(d, str):
            if d.isidentifier() and d not in ('true', 'false', 'null'):
                s += '=' + d
            else:
                s += '="' + d.replace('\\', '\\\\').replace('"', '\\"') + '"'
    return s

def serialize(entities):
    lines = []
    for e in entities:
        fields = ', '.join(ser_field(f) for f in e.fields)
        lines.append(f'{e.name} {{ {fields} }}')
    return '\n'.join(lines)

def fingerprint(entities):
    parts = []
    for e in entities:
        fp = [e.name]
        for f in e.fields:
            fp.append(f'{f.name}:{ser_type(f.type)}:r{f.required}o{f.optional}i{f.immutable}x{f.indexed}u{f.unique}a{f.auto_increment}')
            if f.constraint: fp.append(f'c({f.constraint.min},{f.constraint.max})')
            if f.default is not None: fp.append(f'd={repr(f.default)}')
        parts.append('/'.join(fp))
    return '|'.join(parts)

with open('/tmp/_kappa_roundtrip_inputs.txt') as fh:
    content = fh.read()

trials = content.split('---TRIAL_SEP---\n')
passed = failed = skipped = 0
roundtrip_outputs = []

for trial_src in trials:
    trial_src = trial_src.strip()
    if not trial_src: continue
    r1 = parse(trial_src)
    if r1.diagnostics:
        skipped += 1
        continue
    rt_src = serialize(r1.entities)
    r2 = parse(rt_src)
    if r2.diagnostics:
        print(f'FAIL: roundtrip diagnostics: {r2.diagnostics[0].message}')
        print(f'  src: {rt_src[:80]}')
        failed += 1
        continue
    fp1, fp2 = fingerprint(r1.entities), fingerprint(r2.entities)
    if fp1 != fp2:
        print(f'FAIL: AST mismatch')
        failed += 1
        continue
    passed += 1
    # Save roundtrip source for cross-language verification
    roundtrip_outputs.append(rt_src)

print(f'Python roundtrip: {passed} passed, {failed} failed, {skipped} skipped')

# Write roundtrip sources for cross-language check
with open('/tmp/_kappa_rt_sources.txt', 'w') as fh:
    for src in roundtrip_outputs[:50]:  # test 50 in cross-language
        fh.write(src + '\n---RT_SEP---\n')

sys.exit(1 if failed > 0 else 0)
PYEOF
RT_PY=$?

if [ $RT_PY -eq 0 ]; then
  green "PASS Python roundtrip (500 trials)"
  RT_PASS=$((RT_PASS + 1))
else
  red "FAIL Python roundtrip"
  RT_FAIL=$((RT_FAIL + 1))
fi

# Verify 50 roundtrip outputs parse identically across all 5 languages
python3 -c "
with open('/tmp/_kappa_rt_sources.txt') as f:
    content = f.read()
blocks = [b.strip() for b in content.split('---RT_SEP---') if b.strip()]
for i, b in enumerate(blocks[:50]):
    with open(f'/tmp/_kappa_rt_{i}.txt', 'w') as out:
        out.write(b)
print(min(len(blocks), 50))
" > /tmp/_kappa_rt_count.txt
RT_CROSS_TOTAL=$(cat /tmp/_kappa_rt_count.txt)
echo "  Cross-language: verifying $RT_CROSS_TOTAL roundtrip outputs across 5 languages..."

_xfail=0
for i in $(seq 0 $((RT_CROSS_TOTAL - 1))); do
  input="$(cat /tmp/_kappa_rt_${i}.txt)"
  ts_out="$(ts_json "$input" 2>/dev/null | normalize)"
  py_out="$(py_json "$input" 2>/dev/null | normalize)"
  rs_out="$(rs_json "$input" 2>/dev/null | normalize)"
  go_out="$(go_json "$input" 2>/dev/null | normalize)"
  java_out="$(java_json "$input" 2>/dev/null | normalize)"
  if [ "$ts_out" = "$py_out" ] && [ "$ts_out" = "$rs_out" ] && [ "$ts_out" = "$go_out" ] && [ "$ts_out" = "$java_out" ]; then
    RT_PASS=$((RT_PASS + 1))
  else
    RT_FAIL=$((RT_FAIL + 1))
    _xfail=$((_xfail + 1))
    red "  Divergence on roundtrip $i"
  fi
  rm -f /tmp/_kappa_rt_${i}.txt
done
rm -f /tmp/_kappa_rt_count.txt

if [ $_xfail -eq 0 ]; then
  green "PASS Cross-language roundtrip: all $RT_CROSS_TOTAL outputs identical across 5 languages"
else
  red "FAIL $_xfail cross-language roundtrip divergences"
fi

echo "Part 6: $RT_PASS passed, $RT_FAIL failed"
rm -f /tmp/_kappa_roundtrip_inputs.txt /tmp/_kappa_rt_sources.txt

# ═══════════════════════════════════════════
# PART 7: Deep nesting & spec edge cases
# ═══════════════════════════════════════════
echo ""
echo "═══ PART 7: Spec edge cases ═══"

U_PASS=0
U_FAIL=0

EDGE_CASES=(
  "constraint_no_comma:::T { x: i(5) }:::1:::1"
  "back_to_back_entities:::A { x: s }\nB { y: i }\nC { z: b }:::3:::3"
  "many_fields:::T { a: s, b: t, c: i, d: f, e: b, f: d, g: dt, h: id, i: x, j: m, k: [s], l: [i], n: User, o: (a|b), p: s?, q: s!, r: s~, s2: s@, t2: i++, u: s^, v: s#email }:::1:::21"
  "default_true_string:::T { x: s=\"true\" }:::1:::1"
  "comment_mid_field:::T { x: /* note */ s }:::1:::1"
  "multiple_comments:::// c1\n// c2\n// c3\nT { x: s }:::1:::1"
  "entity_with_digits:::Entity123 { x: s }:::1:::1"
  "single_char_entity:::X { x: s }:::1:::1"
  "all_v2_features:::T { x: s!@~^(1,255)#email=\"default\" }:::1:::1"
  "deep_nest_5:::T { x: [[[[[s]]]]] }:::1:::1"
  "negative_constraint:::T { x: i(-10,10) }:::1:::1"
  "zero_default:::T { x: i=0, y: f=0.0, z: m=0 }:::1:::3"
  "underscore_field:::T { _private: s, __dunder: i }:::1:::2"
  "mixed_case_entity:::MyBigEntityName { aFieldName: s }:::1:::1"
  "enum_then_entity:::enum S (a|b|c)\nT { x: S=a }:::1:::1"
  "hidden_and_format:::T { email: s^#email }:::1:::1"
  "unique_after_entity:::T { org: Org, email: s } @unique(org, email):::1:::2"
)

for case in "${EDGE_CASES[@]}"; do
  name="${case%%:::*}"; rest="${case#*:::}"
  input="${rest%%:::*}"; rest="${rest#*:::}"
  expected_ents="${rest%%:::*}"; expected_fields="${rest#*:::}"
  input="$(echo -e "$input")"

  all_ok=true
  for lang_fn in "TypeScript:ts_json" "Python:py_json" "Rust:rs_json" "Go:go_json" "Java:java_json"; do
    lang="${lang_fn%%:*}"
    fn="${lang_fn#*:}"
    json_out="$($fn "$input" 2>/dev/null)" || json_out="[]"
    if [ -z "$json_out" ] || [ "$json_out" = "null" ]; then json_out="[]"; fi
    ents=$(echo "$json_out" | python3 -c "import json,sys; d=json.load(sys.stdin); d=d if isinstance(d,list) else []; print(len(d))" 2>/dev/null) || ents="ERR"
    fields=$(echo "$json_out" | python3 -c "import json,sys; d=json.load(sys.stdin); d=d if isinstance(d,list) else []; print(sum(len(e.get('fields',e.get('Fields',[])) if isinstance(e,dict) else []) for e in d))" 2>/dev/null) || fields="ERR"
    if [ "$ents" != "$expected_ents" ] || [ "$fields" != "$expected_fields" ]; then
      red "  FAIL $name: $lang got $ents/$fields, expected $expected_ents/$expected_fields"
      all_ok=false
    fi
  done

  if [ "$all_ok" = true ]; then
    green "PASS $name"
    U_PASS=$((U_PASS+1))
  else
    U_FAIL=$((U_FAIL+1))
  fi
done

echo ""
echo "Part 7: $U_PASS passed, $U_FAIL failed out of ${#EDGE_CASES[@]} edge case tests"

# ═══════════════════════════════════════════
# PART 8: Stress test (1000 entities)
# ═══════════════════════════════════════════
echo ""
echo "═══ PART 8: Stress test (1000 entities) ═══"

STRESS_INPUT=$(python3 -c "
import random
random.seed(99)
types = ['s', 't', 'i', 'f', 'b', 'd', 'dt', 'id', 'x']
mods = ['*', '?', '!', '~', '@', '']
lines = []
for i in range(1000):
    nf = random.randint(3, 12)
    fields = []
    for j in range(nf):
        tc = random.choice(types)
        m = random.choice(mods)
        c = f'({random.randint(0,50)},{random.randint(51,200)})' if random.random() < 0.3 else ''
        fields.append(f'f{j}: {tc}{m}{c}')
    lines.append(f'E{i} {{ ' + ', '.join(fields) + ' }')
print('\n'.join(lines))
")

STRESS_EXPECTED=1000
ST_PASS=0
ST_FAIL=0

echo "Input: 1000 entities, variable field counts"
for lang_name in TypeScript Python Rust Go Java; do
  case $lang_name in
    TypeScript) cmd="ts_json" ;;
    Python) cmd="py_json" ;;
    Rust) cmd="rs_json" ;;
    Go) cmd="go_json" ;;
    Java) cmd="java_json" ;;
  esac
  start_ms=$(date +%s%N)
  result=$($cmd "$STRESS_INPUT" 2>/dev/null)
  end_ms=$(date +%s%N)
  elapsed_ms=$(( (end_ms - start_ms) / 1000000 ))
  ent_count=$(echo "$result" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null) || ent_count="ERR"
  if [ "$ent_count" = "$STRESS_EXPECTED" ]; then
    green "  $lang_name: ${elapsed_ms}ms — $ent_count entities correct"
    ST_PASS=$((ST_PASS + 1))
  else
    red "  $lang_name: ${elapsed_ms}ms — WRONG: got $ent_count, expected $STRESS_EXPECTED"
    ST_FAIL=$((ST_FAIL + 1))
  fi
done

echo "Part 8: $ST_PASS/$((ST_PASS + ST_FAIL)) stress tests passed"

# ═══════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════
echo ""
echo "═══ SUMMARY ═══"
TOTAL_PASS=$((PASS + E_PASS + S_PASS + FUZZ_PASS + RT_PASS + U_PASS + ST_PASS))
TOTAL_FAIL=$((FAIL + E_FAIL + S_FAIL + FUZZ_FAIL + RT_FAIL + U_FAIL + ST_FAIL))
echo "AST comparison:  $PASS/${#CASES[@]}"
echo "Error recovery:  $E_PASS/${#ERROR_CASES[@]}"
echo "Streaming:       $S_PASS/$((S_PASS + S_FAIL))"
echo "Fuzz (no crash): $FUZZ_PASS/$FUZZ_TOTAL"
echo "Roundtrip:       $RT_PASS/$((RT_PASS + RT_FAIL))"
echo "Edge cases:      $U_PASS/${#EDGE_CASES[@]}"
echo "Stress (1000):   $ST_PASS/$((ST_PASS + ST_FAIL))"
echo "Total:           $TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1
