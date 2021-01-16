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
    int[2] right;
}

struct TerminalRule {
    int idx;
    string s;
}

class CYK {
    this(string[] rules, string S = "S") {
        const cnf = rules.map!parseProductionRule.array.simplify.ChomskyNormalForm(S);
        int idx;
        foreach (name, expansions; cnf) {
            toIdx[name] = idx;
            idx += 1;
        }

        foreach (name, expansions; cnf) {
            foreach (expansion; expansions) {
                if (expansion.length == 2) {
                    productionRules ~= ProductionRule(toIdx[name], [toIdx[expansion[0]], toIdx[expansion[1]]]);
                } else if (expansion.length == 1) {
                    terminalRules ~= TerminalRule(toIdx[name], expansion[0][1..$-1]);
                }
            }
        }
    }

    private ProductionRule[] productionRules;
    private TerminalRule[] terminalRules;
    private int[string] toIdx;

    /**
    Checks if the sentence matches the defined context-free grammar
     */
    bool check(string[] word) {
        const n = word.length.to!int;
        const r = toIdx.length;

        bool[][][] P = new bool[][][](n, n, r);
        foreach (s, c; word) {
            foreach (rule; terminalRules) {
                if (rule.s == c)
                    P[0][s][rule.idx] = true;
            }
        }

        foreach (l; 2 .. n+1) {
            foreach (s; 0 .. n-l+1) {
                foreach (p; 1 .. l) {
                    foreach (production; productionRules) {
                        if (P[p-1][s][production.right[0]]
                                && P[l-p-1][s+p][production.right[1]])
                            P[l-1][s][production.idx] = true;
                    }
                }
            }
        }

        return P[n-1][0][toIdx["S0"]];
    }

    /**
    Checks if the sentence (here in the form of a single string) matches the defined context-free grammar
    This method only works, if every terminal is a single character.
     */
    bool check(string word) {
        return check(word.map!(to!string).array);
    }
}
@("CYK")
unittest {
    {
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
    {
        string[] rules = [
            `S → "a"`,
            `S →`
        ];
        CYK cyk = new CYK(rules, "S");  // TODO
        assert(cyk.check("a".split));
    }
    {
        string[] rules = [
            `FunctionDeclaration → ReturnType FunctionName "(" OptionalParameters ")"`,
            `ReturnType → Type`,
            `Type → IntType | FloatingType | "void" | "string"`,
            `IntType → "int" | "long"`,
            `FloatingType → "float" | "double"`,
            `FunctionName → "foo" | "bar" | "baz"`,
            `OptionalParameters → Parameters`,
            `OptionalParameters →`,
            `Parameters → Type ParameterName | Type ParameterName "," Parameters`,
            `ParameterName → "a" | "b" | "c"`
        ];

        CYK cyk = new CYK(rules, "FunctionDeclaration");

        // some valid function declarations
        assert(cyk.check("double foo ( )".split));
        assert(cyk.check("string bar ( int a )".split));
        assert(cyk.check("void baz ( int a , float b , long c )".split));

        // some invalid function declarations
        assert(!cyk.check("double foo ( int )".split));
        assert(!cyk.check("string ( int a )".split));
        assert(!cyk.check("void baz ( int a float b , long c )".split));
    }
    {
        string[] rules = [
            `A → "a"`,
            `B → "b"`,
            `Double → A A | B B`,
            `Different → A B | B A`,
            `Expr → Double ">" Different | Different "<" Double`
        ];

        CYK cyk = new CYK(rules, "Expr");

        assert(cyk.check("ab<aa"));
        assert(cyk.check("ba<aa"));
        assert(cyk.check("ab<bb"));
        assert(cyk.check("ba<bb"));
        assert(cyk.check("aa>ab"));
        assert(cyk.check("aa>ba"));
        assert(cyk.check("bb>ab"));
        assert(cyk.check("bb>ba"));
        assert(!cyk.check("aa>aa"));
        assert(!cyk.check("aa=aa"));
        assert(!cyk.check("ab>ba"));
    }
}
