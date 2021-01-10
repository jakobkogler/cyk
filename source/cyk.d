import std.array : array, split, byPair, assocArray;
import std.algorithm : map;
import std.regex : ctRegex, match, matchAll;
import std.typecons : Tuple;

alias Expansion = string[];
alias Expansions = Expansion[];

struct ParsedRule {
    string left;
    Expansions expansions;
}

ParsedRule parseProductionRule(in string rule) {
    static const re = ctRegex!`^\s*(\w+)\s*→([\w"|\s]+)$`;
    const m = match(rule, re);
    const c = m.captures;

    string[] parseExpansion(in string expansion) {
        static const re = ctRegex!`(\w+)|("\w+")`;
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
}

bool isTerminalRule(T)(in T production) {
    return production.value.length == 1 && production.value[0].length == 1
        && production.value[0][0].isTerminal;
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

bool isTerminal(in string s) {
    return s[0] == '"';
}

auto TERM(Expansions[string] productions) {
    Expansions[string] newUnitProductions;

    auto TERM_Expansion(Expansion expansion) {
        Expansion newExpansion;
        foreach (token; expansion) {
            if (token.isTerminal) {
                string nonTerminal = "Unit_" ~ token[1..$-1];
                newUnitProductions[nonTerminal] = [[token]];
                newExpansion ~= nonTerminal;
            } else {
                newExpansion ~= token;
            }
        }
        return newExpansion;
    }

    alias KeyValue = Tuple!(string, "key", Expansions, "value");
    auto TERM_Production(KeyValue production) {
        if (production.isTerminalRule) {
            return production;
        } else {
            return KeyValue(production.key, production.value.map!TERM_Expansion.array);
        }
    }

    auto newProductions = productions.byPair.map!TERM_Production.array;
    return (newProductions ~ newUnitProductions.byPair.array).assocArray;
}
@("TERM")
unittest {
    {
        auto productions = ["Foo": [["A", "B"], ["B", "A"]],
                            "A": [[`"a"`]],
                            "B": [[`"b"`]]
        ];
        auto expected = productions.dup;
        assert(TERM(productions) == expected);
    }

    {
        auto productions = ["Foo": [["A", `"c"`, "B"], ["B", "A"]],
                            "A": [[`"a"`]],
                            "B": [[`"b"`]]
        ];
        auto expected = ["Foo": [["A", "Unit_c", "B"], ["B", "A"]],
                          "A": [[`"a"`]],
                          "B": [[`"b"`]],
                          "Unit_c": [[`"c"`]]
        ];
        assert(TERM(productions) == expected);
    }

    {
        auto productions = ["Foo": [[`"*"`, "Bar", `"*"`]],
                            "Bar": [[`"a"`], [`"b"`]]
        ];
        auto expected = ["Foo": [["Unit_*", "Bar", "Unit_*"]],
                         "Bar": [["Unit_a"], ["Unit_b"]],
                         "Unit_*": [[`"*"`]],
                         "Unit_a": [[`"a"`]],
                         "Unit_b": [[`"b"`]]
        ];
        assert(TERM(productions) == expected);
    }
}
