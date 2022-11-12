%option noyywrap
%option yylineno
%{
    #include "globals.h"
    #include "utility.h"
    #include "y.tab.h"
    
    using namespace std;
	extern SymbolTable* table;

	// typedef pair<string,string> pss;
    Util utility;


    void yyerror(char *);


%}

%x STRING
%x COMMENT_MULT

digit [0-9]
digits {digit}+
letter [a-zA-Z]
letter_ [a-zA-Z_]

nl "\n"
rdx "\."
sq "\'"
bs "\\"

rdx_num {digits}{rdx}{digits}?|{digits}?{rdx}{digits}
expo_num_till_e (({rdx_num}|{digits})[Ee][+-]?)
expo_num ({expo_num_till_e}{digits})

float ({rdx_num}|{expo_num})
unfinished_char {sq}(([^\\\n\'])|({bs}[nt\\\'afrbv0])) 
const_char {unfinished_char}{sq}
digitRdx ({digit}|{rdx})* 
ID ({letter_}({letter_}|{digit})*) 

%%

\" {
    BEGIN STRING;
    utility.resetString();
    utility.add(yytext);
}
<STRING>\\\\ {
    utility.add(yytext);
}
<STRING>\\\" {
    utility.add(yytext);

}
<STRING>\\\n {
    utility.add(yytext);
}
<STRING>\\\r\n {
    utility.add(yytext);
}

<STRING>\" {
    utility.add(yytext);
    utility.handleToken(utility.STR, yytext, true);
    BEGIN INITIAL;
}
<STRING>\n {
    utility.add(yytext);
    utility.handleError(utility.UNFINISHED_STRING, utility.aggrString);

    BEGIN INITIAL;
}
<STRING>. {
    utility.add(yytext);
}
<STRING><<EOF>> {
    utility.handleError(utility.UNFINISHED_STRING, utility.aggrString);

    BEGIN INITIAL;
}



"/*" {
    BEGIN COMMENT_MULT;
    utility.resetString();
    utility.add(yytext);
}
<COMMENT_MULT>"*/" {
    utility.add(yytext);
    utility.handleToken(utility.COMM_MULT, yytext, true, false, false);
    BEGIN INITIAL;
}
<COMMENT_MULT>.|(\r)|(\n) {
    utility.add(yytext);
}
<COMMENT_MULT><<EOF>> {
    utility.handleError(utility.UNFINISHED_COMM, utility.aggrString);
    BEGIN INITIAL;
}


"//"(.|(\\(\r)?\n))* {
}

{digits} {
    yylval.info = new SymbolInfo(yytext, "");
    return CONST_INT;
}

{float} {
    yylval.info = new SymbolInfo(yytext, "");

    return CONST_FLOAT;

}
{const_char} {
}
{sq}{sq} {
    utility.handleError(utility.EMPTY_CHAR, yytext);
}

{unfinished_char} {
    utility.handleError(utility.UNFINISHED_CHAR, yytext);
}

{sq}([^\'\r\n]|(\\\'))+{sq} {
    utility.handleError(utility.MULTI_CHAR, yytext);
}

\. {
    utility.handleError(utility.ILL_FORMED, yytext);
    yylval.info = new SymbolInfo(yytext, "");
    return CONST_FLOAT;
}

"if" {
    return IF;
}
"for" {
    return FOR;
}
"do" {
}
"int" {
    yylval.info = new SymbolInfo(yytext, "");
    return INT;
}
"float" {
    yylval.info = new SymbolInfo(yytext, "");
    return FLOAT;
}
"void" {
    yylval.info = new SymbolInfo(yytext, "");
    return VOID;
}
"switch" {
}
"default" {
}
"else" {
    return ELSE;
}
"while" {
    return WHILE;
}
"break" {
}
"char" {
}
"double" {
}
"return" {
    return RETURN;
}
"case" {
}
"continue" {
}
"printf"|"println" {
    return PRINTLN;
}

{ID} {
    yylval.info = new SymbolInfo(yytext, "ID");
    return ID;

}

({digit}|{rdx})+ {
    utility.handleError(utility.TOO_MANY_DECIMAL, yytext);
    yylval.info = new SymbolInfo(yytext, "");
    return CONST_FLOAT;
}

({rdx_num}|{digit})[Ee][+-]?({digit}|{rdx})+ {
    utility.handleError(utility.ILL_FORMED, yytext);
    yylval.info = new SymbolInfo(yytext, "");
    return CONST_FLOAT;
}

({digit}|{rdx})+[Ee][+-]?{digitRdx} {
    utility.handleError(utility.TOO_MANY_DECIMAL, yytext);
    yylval.info = new SymbolInfo(yytext, "");
    return CONST_FLOAT;
}
({digit}|{rdx}|{letter})+ {
    utility.handleError(utility.INVALID_PREF_SUFF, yytext);
    yylval.info = new SymbolInfo(yytext, "ID");
    return ID;
}


[+-] {
    yylval.info = new SymbolInfo(yytext, "");
    return ADDOP;    
}
[\*/%] {
    yylval.info = new SymbolInfo(yytext, "");
    return MULOP;
}
("++") {
    yylval.info = new SymbolInfo(yytext, "");
    return INCOP;
}
("--") {

    yylval.info = new SymbolInfo(yytext, "");
    return DECOP;
}
(<|(<=)|(>)|(>=)|(==)|(!=)) {
    yylval.info = new SymbolInfo(yytext, "");
    return RELOP;
}
= {
    return ASSIGNOP;

}
("&&")|("||") {
    yylval.info = new SymbolInfo(yytext, "");
    return LOGICOP;

}
"!" {
    return NOT;
}
"(" {
    return LPAREN;
}
")" {
    return RPAREN;
}
"{" {
    table->EnterScope();
    gap += "    ";
    return LCURL;
}

"}" {
    return RCURL;

}
"[" {
    return LTHIRD;

}
"]" {
    return RTHIRD;

}
"," {
    return COMMA;

}
";" {
    return SEMICOLON;

}

[ \t\f\r\v] {

}

{nl} {utility.lineCount++;}

. {
    utility.handleError(utility.UNRECOG_CHAR, yytext);   
}
%%

