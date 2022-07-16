#include <fstream>
#include <iostream>
#include "globals.h"

using namespace std;

class Util{

    ofstream lf;
    ofstream tf;
    string charsAfterSlash;
    const int TableCap = 7;
    
public:
    // SymbolTable *table;
    string aggrString;
    int lineCount;
    // int errorCount;


    string CONST_INT = "CONST_INT";
    string CONST_FLOAT = "CONST_FLOAT";
    string CONST_CHAR = "CONST_CHAR";
    string ADDOP = "ADDOP";
    string MULOP = "MULOP";
    string INCOP = "INCOP";
    string RELOP = "RELOP";
    string ASSIGNOP = "ASSIGNOP";
    string LOGICOP = "LOGICOP";
    string NOT = "NOT";
    string LPAREN = "LPAREN";
    string RPAREN = "RPAREN";
    string LCURL = "LCURL";
    string RCURL= "RCURL";
    string LTHIRD = "LTHIRD";
    string RTHIRD = "RTHIRD";
    string COMMA = "COMMA";
    string SEMICOLON = "SEMICOLON";
    string ID = "ID";
    string STR = "STRING";
    string COMM = "COMMENT";
    string COMM_MULT = "COMMENT_MULT";
    string K_IF = "IF";
    string K_FOR = "FOR";
    string K_DO = "DO";
    string K_INT = "INT";
    string K_FLOAT = "FLOAT";
    string K_VOID = "VOID";
    string K_SWITCH = "SWITCH";
    string K_DEFAULT = "DEFAULT";
    string K_ELSE = "ELSE";
    string K_WHILE = "WHILE";
    string K_BREAK = "BREAK";
    string K_CHAR = "CHAR";
    string K_DOUBLE = "DOUBLE";
    string K_RETURN = "RETURN";
    string K_CASE = "CASE";
    string K_CONTINUE = "CONTINUE";
    string UNFINISHED_STRING = "Unterminated STRING";
    string UNFINISHED_COMM = "Unterminated COMMENT";
    string UNRECOG_CHAR = "Unrecognized character";
    string UNFINISHED_CHAR = "Unterminated character";
    string TOO_MANY_DECIMAL = "Too many decimal points";    
    string ILL_FORMED = "Ill formed number";
    string INVALID_PREF_SUFF = "Invalid prefix on ID or invalid suffix on Number";
    string EMPTY_CHAR = "Empty character";
    string MULTI_CHAR = "Multi character constant error";

    Util(){
        // table = new SymbolTable(TableCap);
        lineCount = 1;
        errorCount = 0;
        // lf.open("1805008_log.txt");
        // tf.open("1805008_token.txt");
        charsAfterSlash = "abfnrtv\\'\"0";
    }

    void handleError(string &err, const char* lexeme){
        string t(lexeme);
        handleError(err, t);
    }

    void handleError(string &err, string &lexeme){
        ++errorCount;
        log << "Error at line " << lineCount << ": " << err << " " << lexeme << "\n\n";

        error << "Error at line " << lineCount << ": " << err << " " << lexeme << "\n\n";
    
        // if(err == UNFINISHED_STRING || err == UNFINISHED_COMM)
        //     lineCount += countNewLine(lexeme);
    }


    void printToken(string &token, string &lexeme, bool printLexeme){
        // if(printLexeme){
        //     tf << "<" << token << ", " << lexeme << "> ";            
        // }
        // else{
        //     tf << "<" << token << "> ";            
        // }
    }

    void printLog(string &token, string& lexeme){
        // lf << "\nLine no " << lineCount << ": Token <" << token 
        // << "> Lexeme " << lexeme << " found\n";
    }

    void printLog(string &token, string& processed, string &unprocessed){
        // lf << "\nLine no " << lineCount << ": Token <" << token 
        // << "> Lexeme " << unprocessed << " found --> <" << token << " , " << processed <<  "> \n";
    }


    void handleToken(
        string &token, 
        const char *lexeme,
        bool printLexeme, 
        bool outputToTf = true, 
        bool insert = false
        ){

        string lexemeString = string(lexeme);
        if(token == STR){
            string processed = processString(aggrString);
            printLog(token, processed , aggrString);
            lineCount += countNewLine(aggrString);
            if(outputToTf){
                printToken(token, processed, printLexeme);
                outputToTf = false;
            }

        }
        else if(token == CONST_CHAR){
            string processed;
            if(lexemeString.length() == 3){
                processed = lexemeString[1];
            }
            else{
                processed = processEscapedChar(lexemeString[2]);
            }
            printLog(token, processed, lexemeString);
            if(outputToTf){
                printToken(token, processed, printLexeme);
                outputToTf = false;
            }

        }
        else{
            if(token == COMM_MULT){
                token = COMM;
                lexemeString = aggrString;
            }
            printLog(token, lexemeString);
            if(token == COMM){
                lineCount += countNewLine(lexemeString);
            }
        }

        if(outputToTf)
            printToken(token, lexemeString, printLexeme);
        
        if(insert){
            // table->Insert(new SymbolInfo(lexemeString, token), lf);
        }
    }

    void resetString(){
        aggrString = "";
    }

    void add(const char* v){
        aggrString += string(v);
    }


    char processEscapedChar(char curr){
        char s = 0;
        switch (curr){
            case 'a':
                s = '\a';
                break;
            case 'b':
                s = '\b';
                break;
            case 'f':
                s = '\f';
                break;
            case 'n':
                s = '\n';
                break;
            case 'r':
                s = '\r';
                break;
            case 't':
                s = '\t';
                break;
            case 'v':
                s = '\v';
                break;
            case '\\':
                s = '\\';
                break;
            case '\'':
                s = '\'';
                break;
            case '"':
                s = '"';
                break;
            case '0':
                s = '\0';
                break;
            default:
                s = '\0';
        }
        return s;
    }

    string processString(string &lexeme){
        if(lexeme.length() == 0) return lexeme;
        string s;
        string::iterator curr = lexeme.begin();
        string::iterator temp = lexeme.begin();
        bool escape = false;
        while(curr != lexeme.end()){
            if(!escape && *curr == '\\'){
                escape = true;
            }
            else if(escape){
                if(*curr == '\n'){
                }
                else if((curr+1) != lexeme.end() && *(curr+1) == '\n'){
                    ++curr;
                }
                else{
                    char t = processEscapedChar(*curr);
                    if(t != '\0' || *curr == '\0'){
                        s += t;
                    }
                    else{
                        s += *curr;
                    }
                }
                escape = false ;
            }
            else{
                s += *curr;
            }
            ++curr;
        }

        return s;
    }


    int countNewLine(string &s){
        int c = 0;
        int m = s.length();
        for(int i = 0; i < m; ++i){
            if(s[i] == '\n') ++c;
        }
        return c;
    }

    void end(){
        // table->PrintAllScopeTable(lf);
        // lf << "Total lines: " << lineCount << "\nTotal errors: " << errorCount
        // << "\n";
    }
};
