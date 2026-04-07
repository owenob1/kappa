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
