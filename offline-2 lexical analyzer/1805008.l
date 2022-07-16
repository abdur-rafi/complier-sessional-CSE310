%option noyywrap

%{
    #include <stdio.h>
    #include "utility.h"
    Util utility;
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
    utility.handleToken(utility.COMM, yytext, true, false, false);
}

{digits} {
    utility.handleToken(utility.CONST_INT, yytext, true, true, true);
}

{float} {
    utility.handleToken(utility.CONST_FLOAT, yytext, true, true, true);

}
{const_char} {
    utility.handleToken(utility.CONST_CHAR, yytext, true, true, true);
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
}

{digitRdx} {
    utility.handleError(utility.TOO_MANY_DECIMAL, yytext);
}

({rdx_num}|{digit})[Ee][+-]?{digitRdx} {
    utility.handleError(utility.ILL_FORMED, yytext);
}

({digitRdx})[Ee][+-]?{digitRdx} {
    utility.handleError(utility.TOO_MANY_DECIMAL, yytext);
}


"if" {
    utility.handleToken(utility.K_IF, yytext, false);
}
"for" {
    utility.handleToken(utility.K_FOR, yytext, false);
}
"do" {
    utility.handleToken(utility.K_DO, yytext, false);
}
"int" {
    utility.handleToken(utility.K_INT, yytext, false);
}
"float" {
    utility.handleToken(utility.K_FLOAT, yytext, false);
}
"void" {
    utility.handleToken(utility.K_VOID, yytext, false);
}
"switch" {
    utility.handleToken(utility.K_SWITCH, yytext, false);
}
"default" {
    utility.handleToken(utility.K_DEFAULT, yytext, false);
}
"else" {
    utility.handleToken(utility.K_ELSE, yytext, false);
}
"while" {
    utility.handleToken(utility.K_WHILE, yytext, false);
}
"break" {
    utility.handleToken(utility.K_BREAK, yytext, false);
}
"char" {
    utility.handleToken(utility.K_CHAR, yytext, false);
}
"double" {
    utility.handleToken(utility.K_DOUBLE, yytext, false);
}
"return" {
    utility.handleToken(utility.K_RETURN, yytext, false);
}
"case" {
    utility.handleToken(utility.K_CASE, yytext, false);
}
"continue" {
    utility.handleToken(utility.K_CONTINUE, yytext, false);
}

{ID} {
    utility.handleToken(utility.ID, yytext, true, true, true);

}

({digitRdx})[Ee]?[+-]?{digitRdx}{ID} {
    utility.handleError(utility.INVALID_PREF_SUFF, yytext);
}


[+-] {
    utility.handleToken(utility.ADDOP, yytext, true);
    
}
[\*/%] {
    utility.handleToken(utility.MULOP, yytext, true);

}
("++"|"--") {
    utility.handleToken(utility.INCOP, yytext, true);

}
(<|(<=)|(>)|(>=)|(==)|(!=)) {
    utility.handleToken(utility.RELOP, yytext, true);
}
= {
    utility.handleToken(utility.ASSIGNOP, yytext, true);

}
("&&")|("||") {
    utility.handleToken(utility.LOGICOP, yytext, true);

}
"!" {
    utility.handleToken(utility.NOT, yytext, true);

}
"(" {
    utility.handleToken(utility.LPAREN, yytext, true);

}
")" {
    utility.handleToken(utility.RPAREN, yytext, true);

}
"{" {
    utility.table->EnterScope();
    utility.handleToken(utility.LCURL, yytext, true);

}

"}" {
    utility.table->ExitScope();
    utility.handleToken(utility.RCURL, yytext, true);

}
"[" {
    utility.handleToken(utility.LTHIRD, yytext, true);

}
"]" {
    utility.handleToken(utility.RTHIRD, yytext, true);

}
"," {
    utility.handleToken(utility.COMMA, yytext, true);

}
";" {
    utility.handleToken(utility.SEMICOLON, yytext, true);

}

[ \t\f\r\v] {

}

{nl} {utility.lineCount++;}

. {
    utility.handleError(utility.UNRECOG_CHAR, yytext);   
}
%%

int main(int argc, char *argv[]){

    if(argc < 2){
        cout << "No file name given\n";
        return 0;
    }
    
    yyin = fopen(argv[1], "r");
    if(!yyin){
        cout << "File could not be opened\n";
        return 0;
    }
    yylex();

    utility.end();

    return 0;
    
}
