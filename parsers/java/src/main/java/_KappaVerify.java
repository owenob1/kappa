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
