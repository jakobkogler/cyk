import std.array : array, split;
import std.algorithm : map;
import std.regex : ctRegex, match, matchAll;

struct ProductionRule {
    string nontermal;
    string[][] expansions;
}

ProductionRule parseProductionRule(in string rule) {
    static const re = ctRegex!`^\s*(\w+)\s*→([\w"|\s]+)$`;
    const m = match(rule, re);
    const c = m.captures;

    string[] parseExpansion(in string expansion) {
        static const re = ctRegex!`(\w+)|("\w+")`;
        return matchAll(expansion, re).map!"a.hit".array;
    }

    auto expansions = c[2].split("|").map!parseExpansion.array;
    return ProductionRule(c[1], expansions);
}
unittest {
    void check(string rule, ProductionRule expected) {
        const parsed = parseProductionRule(rule);
        assert(parsed == expected);
    }

    check(`Foo → A B | C`, ProductionRule("Foo", [["A", "B"], ["C"]]));
    check(`Bar → "baz" B | C`, ProductionRule("Bar", [[`"baz"`, "B"], ["C"]]));
    check(`Foo → A | B | C`, ProductionRule("Foo", [["A"], ["B"], ["C"]]));
    check(`Baz → Foo Bar`, ProductionRule("Baz", [["Foo", "Bar"]]));
    check(`Baz → "a" "b"`, ProductionRule("Baz", [[`"a"`, `"b"`]]));
    check(`Bar → "bar"`, ProductionRule("Bar", [[`"bar"`]]));
}
