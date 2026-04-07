package dev.kappa;

import java.io.*;
import java.nio.file.*;
import java.util.*;

public class Verify {
    public static void main(String[] args) throws Exception {
        Path dir = Path.of("/tmp/kappa/examples/dense");
        int ok = 0, total = 0;
        List<Path> files = new ArrayList<>();
        try (var s = Files.list(dir)) {
            s.filter(p -> p.toString().endsWith(".kappa")).sorted().forEach(files::add);
        }
        for (Path p : files) {
            total++;
            String src = Files.readString(p);
            var result = KappaParser.parse(src);
            int fields = result.entities().stream().mapToInt(e -> e.fields().size()).sum();
            if (result.diagnostics().isEmpty()) {
                System.out.printf("PASS %s: %d entities, %d fields%n", p.getFileName(), result.entities().size(), fields);
                ok++;
            } else {
                System.out.printf("FAIL %s: %s%n", p.getFileName(), result.diagnostics().get(0).message());
            }
        }
        System.out.printf("%d/%d passed%n", ok, total);
        if (ok != total) System.exit(1);
    }
}
