import std.array : array, split;
import std.algorithm : map;
import std.regex : ctRegex, match, matchAll;

import utils : Expansions;

struct ParsedRule {
    string left;
    Expansions expansions;
}

ParsedRule parseProductionRule(in string rule) {
    static const re = ctRegex!`^\s*(\w+)\s*→(.+)$`;
    const m = match(rule, re);
    const c = m.captures;

    string[] parseExpansion(in string expansion) {
        static const re = ctRegex!`(\w+)|("[^"]+")`;
        return matchAll(expansion, re).map!"a.hit".array;
    }

    auto expansions = c[2].split("|").map!parseExpansion.array;
    return ParsedRule(c[1], expansions);
}
@("parse rules")
unittest {
    void check(string rule, ParsedRule expected) {
        const parsed = parseProductionRule(rule);
        assert(parsed == expected);
    }

    check(`Foo → A B | C`, ParsedRule("Foo", [["A", "B"], ["C"]]));
    check(`Bar → "baz" B | C`, ParsedRule("Bar", [[`"baz"`, "B"], ["C"]]));
    check(`Foo → A | B | C`, ParsedRule("Foo", [["A"], ["B"], ["C"]]));
    check(`Baz → Foo Bar`, ParsedRule("Baz", [["Foo", "Bar"]]));
    check(`Baz → "a" "b"`, ParsedRule("Baz", [[`"a"`, `"b"`]]));
    check(`Bar → "bar"`, ParsedRule("Bar", [[`"bar"`]]));
    check(`Primary → number | variable | "(" Expr ")"`,
          ParsedRule("Primary", [["number"], ["variable"], [`"("`, "Expr", `")"`]]));
}

auto simplify(ParsedRule[] rules) {
    Expansions[string] productions;

    foreach (rule; rules) {
        productions[rule.left] ~= rule.expansions.dup;
    }
    return productions;
}
@("simplify")
unittest {
    {
        auto rules = [ParsedRule("Foo", [["A", "B"], ["B", "A"]]),
                      ParsedRule("A", [[`"a"`]]),
                      ParsedRule("B", [[`"b"`]])];
        auto expected = ["Foo": [["A", "B"], ["B", "A"]],
                         "A": [[`"a"`]],
                         "B": [[`"b"`]]];
        assert(rules.simplify == expected);
    }
    {
        auto rules = [ParsedRule("Foo", [["A", "B"], ["B", "A"]]),
                      ParsedRule("Foo", [[`"a"`]]),
                      ParsedRule("B", [[`"b"`]])];
        auto expected = ["Foo": [["A", "B"], ["B", "A"], [`"a"`]],
                         "B": [[`"b"`]]];
        assert(rules.simplify == expected);
    }
}
