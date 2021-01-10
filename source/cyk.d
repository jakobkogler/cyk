import std.array : array, split;
import std.algorithm : map, filter;
import std.conv : to;
import std.regex : ctRegex, match, matchAll;
import std.typecons : Tuple, tuple;

struct ProductionRule {
    string left;
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

struct UnitProduction {
    string variable;
    int left;
    string right;
}

struct MultiProduction {
    string variable;
    int left;
    int[][] right;
}

bool isTerminalRule(in ProductionRule rule) {
    return rule.expansions.length == 1 && rule.expansions[0].length == 1
        && rule.expansions[0][0][0] == '"';
}

Tuple!(UnitProduction[], MultiProduction[]) toNumbers(ProductionRule[] rules) {
    /* return tupleof */
    UnitProduction[] unitProductions;
    MultiProduction[] multiProductions;
    int[string] nonterminals;

    // find indices for nonterminals
    foreach (rule; rules) {
        if (!(rule.left in nonterminals)) {
            nonterminals[rule.left] = nonterminals.length.to!int;
        }
    }

    // now replace tokens with indices, and simultaniously do TERM
    int numberNonTerminals = nonterminals.length.to!int;
    foreach (rule; rules) {
        if (rule.isTerminalRule) {
            unitProductions ~= UnitProduction(rule.left, nonterminals[rule.left], rule.expansions[0][0][1..$-1]);
        } else {
            int[] toIndices(string[] tokens) {
                int[] indices;
                foreach (token; tokens) {
                    if (token[0] == '"') {
                        unitProductions ~= UnitProduction("", numberNonTerminals, token[1..$-1]);
                        indices ~= numberNonTerminals;
                        numberNonTerminals++;
                    } else {
                        indices ~= nonterminals[token];
                    }
                }
                return indices;
            }

            multiProductions ~= MultiProduction(rule.left,
                                                nonterminals[rule.left],
                                                rule.expansions.map!toIndices.array);
        }
    }

    return tuple(unitProductions, multiProductions);
}
unittest {
    {
        auto rules = [ProductionRule("Foo", [["A", "B"], ["B", "A"]]),
                      ProductionRule("A", [[`"a"`]]),
                      ProductionRule("B", [[`"b"`]])];
        const expectedUP = [UnitProduction("A", 1, "a"), UnitProduction("B", 2, "b")];
        const expectedMP = [MultiProduction("Foo", 0, [[1, 2], [2, 1]])];
        auto result = toNumbers(rules);
        assert(result[0] == expectedUP);
        assert(result[1] == expectedMP);
    }

    {
        auto rules = [ProductionRule("Foo", [["A", `"c"`, "B"], ["B", "A"]]),
                      ProductionRule("A", [[`"a"`]]),
                      ProductionRule("B", [[`"b"`]])];
        const expectedUP = [UnitProduction("", 3, "c"), UnitProduction("A", 1, "a"),
                            UnitProduction("B", 2, "b")];
        const expectedMP = [MultiProduction("Foo", 0, [[1, 3, 2], [2, 1]])];
        auto result = toNumbers(rules);
        assert(result[0] == expectedUP);
        assert(result[1] == expectedMP);
    }

    {
        auto rules = [ProductionRule("Foo", [[`"*"`, "Bar", `"*"`]]),
                      ProductionRule("Bar", [[`"a"`], [`"b"`]])];
        const expectedUP = [UnitProduction("", 2, "*"), UnitProduction("", 3, "*"),
                            UnitProduction("", 4, "a"), UnitProduction("", 5, "b")];
        const expectedMP = [MultiProduction("Foo", 0, [[2, 1, 3]]),
                            MultiProduction("Bar", 1, [[4], [5]])];
        auto result = toNumbers(rules);
        assert(result[0] == expectedUP);
        assert(result[1] == expectedMP);
    }
}
