import std.array : array, split;
import std.algorithm : map;
import std.conv : to;
import std.regex : ctRegex, match, matchAll;

import utils : Expansions, isTerminal;
import chomsky_normal_form : ChomskyNormalForm;

struct ParsedRule {
    string left;
    Expansions expansions;
}

ParsedRule parseProductionRule(in string rule) {
    static const re = ctRegex!`^\s*(\w+)\s*→(.*)$`;
    const m = match(rule, re);
    const c = m.captures;

    string[] parseExpansion(in string expansion) {
        static const re = ctRegex!`(\w+)|("[^"]+")`;
        return matchAll(expansion, re).map!"a.hit".array;
    }

    Expansions expansions;
    if (c[2].length == 0) {
        expansions = [[]];
    } else {
        expansions = c[2].split("|").map!parseExpansion.array;
    }
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
    check(`Foo → `, ParsedRule("Foo", [[]]));
    check(`Foo →`, ParsedRule("Foo", [[]]));
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
    {
        auto rules = [ParsedRule("Foo", [["A"]]),
                      ParsedRule("Foo", [[]])];
        auto expected = ["Foo": [["A"], []]];
        assert(rules.simplify == expected);
    }
    {
        auto rules = [
            `Parameters → Type ParameterName`,
            `Parameters →`,
        ];
        auto expected = ["Parameters": [["Type", "ParameterName"], []]];
        assert(rules.map!parseProductionRule.array.simplify == expected);
    }
}

struct ProductionRule {
    int idx;
    string name;
    string[] right;
}

bool isTerminal(const ProductionRule rule) {
    return rule.right.length == 1 && rule.right[0].isTerminal;
}

class CYK {
    this(string[] rules, string S = "S") {
        this.cnf = rules.map!parseProductionRule.array.simplify.ChomskyNormalForm(S);
        int idx;
        foreach (name, expansions; this.cnf) {
            toIdx[name] = idx;
            foreach (expansion; expansions) {
                productionRules ~= ProductionRule(idx, name, expansion);
            }
            idx += 1;
        }
    }

    private Expansions[string] cnf;
    private ProductionRule[] productionRules;
    private int[string] toIdx;

    bool check(string[] word) {
        const n = word.length.to!int;
        const r = productionRules.length;

        bool[][][] P = new bool[][][](n, n, r);
        foreach (s, c; word) {
            foreach (production; productionRules) {
                if (production.isTerminal && production.right[0][1..$-1] == c)
                    P[0][s][production.idx] = true;
            }
        }

        foreach (l; 2 .. n+1) {
            foreach (s; 0 .. n-l+1) {
                foreach (p; 1 .. l) {
                    foreach (production; productionRules) {
                        if (production.isTerminal)
                            continue;
                        if (P[p-1][s][toIdx[production.right[0]]]
                                && P[l-p-1][s+p][toIdx[production.right[1]]])
                            P[l-1][s][production.idx] = true;
                    }
                }
            }
        }

        return P[n-1][0][toIdx["S0"]];
    }
}
@("CYK")
unittest {
    string[] rules = [
        `Expr → Term | Expr AddOp Term | AddOp Term`,
        `Term → Factor | Term MulOp Factor`,
        `Factor → Primary | Factor "^" Primary`,
        `Primary → number | variable | "(" Expr ")"`,
        `AddOp → "+" | "-"`,
        `MulOp → "*" | "/"`,
        `number → "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"`,
        `variable → "a" | "b" | "c"`
    ];
    CYK cyk = new CYK(rules, "Expr");
    assert(cyk.check("a ^ 2 + 4 * b".split));
    assert(cyk.check("a ^ ( 2 + 4 * b )".split));
    assert(!cyk.check("a ^ 2 + 4 * b )".split));
    assert(cyk.check("+ 5".split));
    assert(!cyk.check("* 5".split));
    assert(cyk.check("a * 5".split));
}
