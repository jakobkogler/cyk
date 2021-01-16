alias Expansion = string[];
alias Expansions = Expansion[];

/**
Checks if a string is a terminal
 */
bool isTerminal(in string s) {
    return s[0] == '"';
}

bool isTerminalRule(T)(in T production) {
    return production.value.length == 1 && production.value[0].length == 1
        && production.value[0][0].isTerminal;
}

bool isTerminal(const Expansion expansion) {
    return expansion.length == 1 && expansion[0].isTerminal;
}
