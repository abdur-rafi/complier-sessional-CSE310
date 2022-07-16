%{
    #include "globals.h"
	#include <fstream>
	

	extern int yylineno;
	SymbolTable* table = new SymbolTable(30);
	using namespace std;

	int errorCount = 0;

	ofstream log("log.txt");
	ofstream error("error.txt");

    int yyparse(void);
    int yylex(void);
    extern FILE *yyin;

	void printLineNo(){
		log << "Line " << yylineno << ": ";
	}

	void print(string s1, string s2){
		printLineNo();
		log << s1 << "\n\n" << s2 << "\n\n";
	}
	void printError(string s1){
		++errorCount;
		log << "Error at line " << yylineno << ": " << s1 << "\n\n";
		error << "Error at line " << yylineno << ": " << s1 << "\n\n";
	}
	void printError(string s1, int lineNo){
		++errorCount;
		log << "Error at line " << lineNo << ": " << s1 << "\n\n";
		error << "Error at line " << lineNo << ": " << s1 << "\n\n";
	}
	void printVoidError(){
		printError("Void function used in expression");
	}
	void printArrayError(string s1){
		printError(s1 + " is an array");
	}

    void yyerror(char *s){
		string t(s);
		printError(t);
    }

	int funcDefStart = 0;

	string currFuncReturnType;
	string currFuncName;
%}

%union{
	string *s;
	SymbolInfo *info;
	vector<string> *v;
	vector<pss> *pv;
	vsPair *vs;
	isPair *is;
	ssPair *ss;
	vsbTriplet *vsb;
	vbsPair *vbs;
	vssPair *vss;
	ssbTriplet *ssb;
	vssbsPair *vssbs;
}


%token <info> IF ELSE FOR WHILE  ADDOP MULOP ASSIGNOP RELOP LOGICOP NOT INT FLOAT RETURN VOID PRINTLN SEMICOLON COMMA LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD INCOP DECOP CONST_INT CONST_FLOAT ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%type <vbs> declaration_list  
%type <vss> parameter_list 
%type <s> type_specifier func_declaration var_declaration unit statement statements compound_statement func_definition program start
%type <ssb> variable factor unary_expression term simple_expression rel_expression logic_expression expression expression_statement 
%type <vssbs> arguments argument_list
%%


start : program {
	$$ = $1;
	print("start : program", "");
	delete $$;
}
;

program : program unit  {
	$$ = new string(*$1 + "\n" +  *$2 );
	print("program : program unit", *$$);
	delete $1;
	delete $2;
}

| unit {
	$$ = $1;
	print("program : unit", *$$);
}
| program error {
	$$ = $1;
} 
| error {
	$$ = new string();
}

;
	
unit : var_declaration {
	$$ = $1;
	print("unit : var_declaration", *$$);

}
| func_declaration {
	$$ = $1;
	print("unit : func_declaration", *$$);

}
| func_definition {
	$$ = $1;
	print("unit : func_definition", *$$);
}

;
     
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON {
	$$ = new string(*$1 + " " + $2->getName() + "(" + $4->s+");" );
	vector<string> t;
	for(auto ss : $4->v){
		t.push_back(ss.first);
	}
	functionInfo *f = new functionInfo(t, *$1);
	SymbolInfo *info = new SymbolInfo($2->getName(),"ID", *$1, nullptr, f);
	set<string> s;
	if(!table->Insert(info)){
		printError("multiple declaration of " + $2->getName());
		delete info;
	}
	else{
		for(auto ss : $4->v){
			if(ss.second.size() > 0){
				if(s.find(ss.second) != s.end()){
					printError("multiple declaratoin of " + ss.second + " in parameters of function declaration");
					break;
				}
				s.insert(ss.second);
			}
		}
	}
	// 									HANDLE ERROR
	delete $1;
	delete $2;
	delete $4;
	print("func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON", *$$);
}
| type_specifier ID LPAREN RPAREN SEMICOLON {
	$$ = new string(*$1 + " " + $2->getName() + "();");
	vector<string> t;
	functionInfo *f = new functionInfo(t, *$1);
	SymbolInfo *info = new SymbolInfo($2->getName(),"ID",*$1, nullptr, f);
	if(!table->Insert(info)){
		printError("multiple declaration of " + $2->getName());
		delete info;
	};
	// 									HANDLE ERROR
	delete $1;
	delete $2;

	print("func_declaration :  type_specifier ID LPAREN RPAREN SEMICOLON ", *$$);
}
;
		 
func_definition : type_specifier ID LPAREN parameter_list RPAREN {
	funcDefStart = yylineno;
	vector<string> t;
	for(auto ss : $4->v){
		t.push_back(ss.first);
	}
	functionInfo *f = new functionInfo(t, *$1, true);
	SymbolInfo *info = new SymbolInfo($2->getName(), "ID", *$1, nullptr, f);
	bool t2 = table->InsertInParent(info);
	if(!t2){
		delete info;
		SymbolInfo *info = table->findInParent($2->getName());
		functionInfo *fInfo = info->getFuncInfo();
		if(fInfo == nullptr || fInfo->defined ){
			printError("multiple declaration of " + $2->getName());
		}
		else{
			int n = fInfo->types.size();
			bool ok = true;
			if(*$1 != fInfo->returnType){
				printError("Return type mismatch with function declaration in function " + $2->getName());
			}
			if(n != $4->v.size()){
				printError("Total number of arguments mismatch with declaration in function " + $2->getName());
				ok = false;
			}
			else{
				for(int i = 0; i < n; ++i){
					if(fInfo->types[i] != $4->v[i].first){
						printError( to_string(i + 1) + "th argument mismatch  with declaration in function " + $2->getName());
						ok = false;
						break;
					}
				}
			}
			if(ok)
				info->getFuncInfo()->defined = true;
		}
	}
	int i = 0;
	for(auto ss : $4->v){
		if(ss.second.size() == 0){
			printError( to_string(i + 1) + "th parameter's name not given in function definition of " + $2->getName());
		}
		else{
			SymbolInfo *info = new SymbolInfo(ss.second, "ID", ss.first);
			bool t2 = table->Insert(info);
			if(!t2){
				printError("multiple declaration of " + info->getName() + " in parameter");
				delete info;
			
			}	
		}
		++i;
	}
	currFuncReturnType = *$1;
	currFuncName = $2->getName();

} compound_statement {
	$$ = new string(*$1 + " " + $2->getName() + "(" + $4->s + ")" + *$7 );

	print("func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement", *$$);

	delete $1;
	delete $2;
	delete $4;
	delete $7;

}
| type_specifier ID LPAREN RPAREN {
	funcDefStart = yylineno;
	vector<string> t;
	functionInfo *f = new functionInfo(t, *$1, true);
	SymbolInfo *info = new SymbolInfo($2->getName(), "ID", *$1, nullptr, f);
	bool t2 = table->InsertInParent(info);
	if(!t2){
		delete info;
		SymbolInfo *info = table->findInParent($2->getName());
		functionInfo *fInfo = info->getFuncInfo();
		if(fInfo == nullptr || fInfo->defined ){
			printError("multiple declaration of " + $2->getName());
		}
		else{
			int n = fInfo->types.size();
			bool ok = true;
			if(*$1 != fInfo->returnType){
				printError("Return type mismatch with function declaration in function " + $2->getName());
			}
			if(n != 0){
				printError("Total number of arguments mismatch with declaration in function " + $2->getName());
				ok = false;
			}
			else{

			}
			if(ok)
				info->getFuncInfo()->defined = true;
		}
	}
	
	currFuncReturnType = *$1;
	currFuncName = $2->getName();

} compound_statement {
	$$ = new string(*$1 + " " + $2->getName() + "()" + *$6);
	vector<string> t;
	functionInfo *f = new functionInfo(t,*$1);
	SymbolInfo *info = new SymbolInfo($2->getName(), "ID", *$1, nullptr, f);
	bool t2 = table->Insert(info);
	
	print("func_definition : type_specifier ID LPAREN RPAREN compound_statement", *$$);

	//  	 					HANDLE ERROR


	delete $1;
	delete $2;
	delete $6;
}
;



parameter_list  : parameter_list COMMA type_specifier ID {
	$1->v.push_back({*$3, $4->getName()});
	$1->s += "," + *$3 + " " + $4->getName();
	$$ = $1;
	delete $3;
	delete $4;
	print("parameter_list : parameter_list COMMA type_specifier ID", $$->s);
}
| parameter_list COMMA type_specifier {
	$1->v.push_back({*$3, ""});
	$1->s += "," + *$3;
	$$ = $1;
	delete $3;
	print("parameter_list : parameter_list COMMA type_specifier", $$->s);
}

| type_specifier ID {
	$$ = new vssPair();
	$$->v.push_back({*$1, $2->getName()});
	$$->s = *$1 + " ";
	$$->s += $2->getName();
	delete $1;
	delete $2;

	print("parameter_list : type_specifier ID", $$->s);
}
| type_specifier {
	$$ = new vssPair();
	$$->v.push_back({*$1, ""});
	$$->s = *$1;
	delete $1;
	print("parameter_list :  type_specifier", $$->s);

}
| parameter_list error type_specifier {
	$1->v.push_back({*$3, ""});
	$1->s += "," + *$3;
	$$ = $1;
	delete $3;
}
| parameter_list error {
	$$ = $1;
}
| error {
	$$ = new vssPair();
}
;

 		
compound_statement : LCURL statements RCURL {
	$$ = new string("{\n" + *$2 + "\n}");
	delete $2;
	print("compound_statement : LCURL statements RCURL", *$$);
}
| LCURL RCURL {
	$$ = new string("{\n\n}");
	print("compound_statement : LCURL RCURL", *$$);

}
;
 		    
var_declaration : type_specifier declaration_list SEMICOLON {
	$$ = new string(*$1 + " " + $2->s + ";");
	
	if(*$1 == "void"){
		printError("Variable type cannot be void");
	}
	else
		for(auto s : $2->v){
			SymbolInfo *info = new SymbolInfo(s.first, "ID", *$1,s.second);
			bool t2 = table->Insert(info);
			if(!t2){
				printError("Multiple declaration of " + s.first);
				delete info;
			}
			//  						CHECK FOR ERROR
		}
	delete $1;
	delete $2;
	print("var_declaration : type_specifier declaration_list SEMICOLON", *$$);
}
;
 		 
type_specifier	: INT {
	$$ = new string($1->getName());
	delete $1;
	print("type_specifier	: INT", *$$);
}
|FLOAT { 
	$$ = new string($1->getName());
	delete $1;
	print("type_specifier	: FLOAT", *$$);
}
|VOID { 
	$$ = new string($1->getName());
	delete $1;
	print("type_specifier	: VOID", *$$);
}
;
 		
declaration_list : declaration_list COMMA ID {
	$1->v.push_back({$3->getName(), false});
	if($1->s.size())
		$1->s += "," + $3->getName();
	else
		$1->s += $3->getName();
	$$ = $1;
	delete $3;
	print("declaration_list : declaration_list COMMA ID", $$->s);
}
| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
	$1->v.push_back({$3->getName(), true});
	if($1->s.size())
		$1->s += "," + $3->getName() + "[" + $5->getName() + "]";
	else
		$1->s +=  $3->getName() + "[" + $5->getName() + "]";
	$$ = $1;
	print("declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD", $$->s);
}
| ID {
	$$ = new vbsPair();
	$$->v.push_back({$1->getName(), false});
	$$->s = $1->getName();

	delete $1;

	print("declaration_list : ID", $$->s);
}
| ID LTHIRD CONST_INT RTHIRD {
	$$ = new vbsPair();
	$$->v.push_back({$1->getName(), true});
	$$->s = $1->getName() + "[" + $3->getName()+"]";

	delete $1;

	print("declaration_list : ID LTHIRD CONST_INT RTHIRD", $$->s);
}
| declaration_list error {
	$$ = $1;
}
| error {
	$$ = new vbsPair();
}
;
 		  
statements : statement {
	$$ = $1;
	print("statements : statement", *$$);
}
| statements statement {
	$$ = new string( *$1 + "\n" + *$2);
	delete $1;
	delete $2;
	print("statements : statements statement", *$$);
}
| statements error {
	$$ = $1;
}   
| error {
	$$ = new string();
}

	   ;
	   
statement : var_declaration {
	$$ = $1;
	print("statement : var_declaration ", *$$);
}
| expression_statement {
	$$ = new string($1->s1);
	delete $1;
	print("statement : expression_statement ", *$$);

}
| compound_statement {
	$$ = $1;
	print("statement :  compound_statement", *$$);

}
| FOR LPAREN expression_statement expression_statement expression RPAREN statement {
	$$ = new string("for("+$3->s1+$4->s1+$5->s1+")"+*$7);
	delete $3;
	delete $4;
	delete $5;
	delete $7;
	print("statement :  FOR LPAREN expression_statement expression_statement expression RPAREN statement", *$$);

}
| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE {
	$$ = new string("if(" + $3->s1 + ")" + *$5);
	delete $3;
	delete $5;
	print("statement :  IF LPAREN expression RPAREN statement ", *$$);

}
| IF LPAREN expression RPAREN statement ELSE statement {
	$$ = new string("if(" + $3->s1 + ")" + *$5 + "\nelse" + *$7);
	delete $3;
	delete $5;
	delete $7;
	print("statement :   IF LPAREN expression RPAREN statement ELSE statement ", *$$);

}
| WHILE LPAREN expression RPAREN statement {
	$$ = new string("while(" + $3->s1 + ")" + *$5);
	delete $3;
	delete $5;	
	print("statement :   WHILE LPAREN expression RPAREN statement ", *$$);

}
| PRINTLN LPAREN ID RPAREN SEMICOLON {
	$$ = new string("printf(" + $3->getName() + ");");
	if(table->LookUp($3->getName()) == nullptr){
		printError("undeclared variable " + $3->getName());
	}
	delete $3;
	print("statement :   PRINTLN LPAREN ID RPAREN SEMICOLON ", *$$);

}
| RETURN expression SEMICOLON {
	$$ = new string("return " + $2->s1 + ";");
	delete $2;
	print("statement :   RETURN expression SEMICOLON  ", *$$);

}
| type_specifier ID LPAREN parameter_list RPAREN {

	printError("invalid scope for defining function " + $2->getName());
	int i = 0;
	for(auto ss : $4->v){
		if(ss.second.size() == 0){
			printError( to_string(i + 1) + "th parameter's name not given in function definition of " + $2->getName());
		}
		else{
			SymbolInfo *info = new SymbolInfo(ss.second, "ID", ss.first);
			bool t2 = table->Insert(info);
			if(!t2){
				printError("multiple declaration of " + info->getName() + " in parameter");
				delete info;
			
			}	
		}
		++i;
	}
	currFuncReturnType = *$1;
	currFuncName = $2->getName();

} compound_statement {
	$$ = new string(*$1 + " " + $2->getName() + "(" + $4->s + ")" + *$7 );

	delete $1;
	delete $2;
	delete $4;
	delete $7;

}
| type_specifier ID LPAREN RPAREN {
	printError("invalid scope for defining function " + $2->getName());
	currFuncReturnType = *$1;
	currFuncName = $2->getName();

} compound_statement {
	$$ = new string(*$1 + " " + $2->getName() + "()" + *$6 );
	delete $1;
	delete $2;
	delete $6;
}
| type_specifier ID LPAREN parameter_list RPAREN SEMICOLON {
	$$ = new string(*$1 + " " + $2->getName() + "(" + $4->s+");" );
	printError("Invalid scope for declaring function " + $2->getName());
	set<string> s;
	for(auto ss : $4->v){
		if(ss.second.size() > 0){
			if(s.find(ss.second) != s.end()){
				printError("multiple declaratoin of " + ss.second + " in parameters of function declaration");
				break;
			}
			s.insert(ss.second);
		}
	}
	
	delete $1;
	delete $2;
	delete $4;

}
| type_specifier ID LPAREN RPAREN SEMICOLON {
	$$ = new string(*$1 + " " + $2->getName() + "();");
	printError("Invalid scope for declaring function " + $2->getName());
	delete $1;
	delete $2;
}
;
	  
expression_statement 	: SEMICOLON	{
	$$ = new ssbTriplet();
	$$->s1 = ";";
	print("expression_statement : SEMICOLON", $$->s1);
}		
| expression SEMICOLON {
	$$ = $1;
	$$->s1 += ";";
	print("expression_statement :  expression SEMICOLON ", $$->s1);

} 
			;
	  
variable : ID {
	SymbolInfo *info;
	$$ = new ssbTriplet();
	$$->s1 = $1->getName();
	// cout << "here";
	if((info = table->LookUp($1->getName())) != nullptr){
		if(info->getFuncInfo() != nullptr){
			printError($1->getName() + " is a function");
			$$->s2 = "u";
		}
		else{
			$$->s2 = info->getDataType();
			$$->b = info->isArray_();
		}
	}
	else{
		printError("Undeclared variable " + $1->getName());
		$$->s2 = "u";
		// 												HANDLE ERROR
	}

	delete $1;
	print("variable : ID", $$->s1);

}
| ID LTHIRD expression RTHIRD {
	$$ = $3;
	$$->s1 = $1->getName() + "[" + $$->s1 + "]";
	if($3->b || $3->s2 != "int"){
		printError("Expression inside third brackets not an integer");
	}
	SymbolInfo *info;
	if((info = table->LookUp($1->getName())) != nullptr){
		$$->s2 = info->getDataType();
		if(!info->isArray_()){
			printError( $1->getName() + " not an array");
		}
		$$->b = false;
	}
	else{
		printError("Undeclared variable " + $1->getName());
		$$->s2 = "u";
		// 												HANDLE ERROR
	}
	print("variable : ID LTHIRD expression RTHIRD", $$->s1);
} 
	 ;
	 
expression : logic_expression {
	$$ = $1;
	print("expression : logic_expression", $$->s1);
}
| variable ASSIGNOP logic_expression {
	$$ = $1;
	if($3->s2 == "void"){
		printVoidError();
		$$->s2 = "u";
	}
	else if($1->b && $3->b){
		printError("Invalid array assignment");
	}
	else if($1->b && !$3->b){
		printError("Type mismatch, " + $1->s1 + " is an array");
	}
	else if(!$1->b && $3->b){
		printError("Type mismatch, " + $3->s1 + " is an array");
	}
	else if(($1->s2 != "float") && ($1->s2 != $3->s2) && ($1->s2 != "u" && $3->s2 != "u")){
		printError("Type mismatch ");
	}
	$$->s1 += "=" + $3->s1;

	delete $3;
	// 										ERROR SOURCE
	print("expression : variable ASSIGNOP logic_expression", $$->s1);
}
	   ;
			
logic_expression : rel_expression 	{
	$$ = $1;
	print("logic_expression : rel_expression ", $$->s1);
	
}
| rel_expression LOGICOP rel_expression {
	
	$$ = $1;
	$$->s1 += $2->getName() + $3->s1;

	if($1->s2 == "void" || $3->s2 == "void"){
		printVoidError();
		$1->s2 = "u";
	}
	else if($1->s2 == "u" || $3->s2 == "u"){
		$1->s2 = "u";
	}
	else
		$$->s2 = "int";

	delete $3;
	print("logic_expression : rel_expression LOGICOP rel_expression", $$->s1);
	
}
;
			
rel_expression	: simple_expression {
	$$ = $1;
	print("rel_expression	: simple_expression  ", $$->s1);
	
}
| simple_expression RELOP simple_expression	{
	$$ = $1;
	$$->s1 += $2->getName() + $3->s1;

	if($1->b && $3->b){
	}
	else if($1->b){
		printArrayError($1->s1);
		$$->s2 = "u";
	}
	else if($3->b){
		printArrayError($3->s1);
		$$->s2 = "u";
	}

	if($1->s2 == "void" || $3->s2 == "void"){
		printVoidError();
		$$->s2 = "u";
	}
	else if( $1->s2 == "u" || $3->s2 == "u"){
		$$->s2 = "u";
	}
	else $$->s2 = "int";


	delete $3;
	print("rel_expression	: simple_expression RELOP simple_expression  ", $$->s1);
}
		;
				
simple_expression : term {
	$$ = $1;
	print("simple_expression : term  ", $$->s1);
	
}
| simple_expression ADDOP term {
	$$ = $1;
	if($2->getName() == "+"){
		if($1->b){
			printArrayError($1->s1);
			$$->s2 = "u";
		}
		if($3->b){
			printArrayError($3->s1);
			$$->s2 = "u";
		}

	}
	else{
		if($1->b && $3->b){
			$$->s2 = "int";
		}
		else if($1->b){
			printArrayError($1->s1);
			$$->s2 = "u";
		}
		else if($3->b){
			printArrayError($3->s1);
			$$->s2 = "u";
		}
	}

	if($1->s2 == "void" || $3->s2 == "void"){
		cout << "Here " << $1->s2 << " " << $3->s1 << "\n";
		printVoidError();
		$$->s2 = "u";
	}
	else if($3->s2 == "u"){
		$$->s2 = "u";
	}
	else if($3->s2 == "float"){
		$$->s2 = "float";
	}

	$$->s1 += $2->getName() + $3->s1;
	$$->b = false;
	delete $3;

	print("simple_expression : simple_expression ADDOP term", $$->s1);
	
} 
		  ;
					
term :	unary_expression {
	$$ = $1;
	print("term :	unary_expression ", $$->s1);
	
}
|  term MULOP unary_expression {
	$$ = $1;

	if($1->b){
		printArrayError($1->s1);
	}
	if($3->b){
		printArrayError($3->s1);
	}
	else if($1->s2 == "void" || $3->s2 == "void"){
		printVoidError();
		$$->s2 = "u";
	}
	else if($3->s2 == "u"){
		$$->s2 = "u";
	}
	else if($2->getName() == "%" && ($1->s2 != "int" || $3->s2 != "int")){
		printError("Non-Integer operand on modulus operator");
		$$->s2 = "u";
	}
	else if(($2->getName() == "%" || $2->getName() == "/") && $3->s1 == "0"){
		printError("Modulus by Zero");
		$$->s2 = "u";		
	}
	else if($3->s2 == "float"){
		$$->s2 = "float";
	}
	
	$$->s1 += $2->getName() + $3->s1;
	$$->b = false;

	delete $3;	

	print("term :	term MULOP unary_expression", $$->s1);
	
}
     ;

unary_expression : ADDOP unary_expression  {
	//  						WHEN DOES THIS MATCH??????????????????????????//
	
	$$ = $2;
	$$->s1 = $1->getName() + $$->s1;
	if($2->b){
		printArrayError($2->s1);
	}
	else if($2->s2 == "void"){
		printVoidError();
		$2->s2 = "u";
	}
	$$->b = false;

	delete $1;
	print("unary_expression : ADDOP unary_expression", $$->s1);
	
}
| NOT unary_expression {
	$$ = $2;
	$$->s1 = "!" + $$->s1;
	$$->b = false;
	if($$->s2 == "void"){
		printVoidError();
		$$->s2 = "u";
	}
	else if($$->s2 == "u"){

	}
	else $$->s2 = "int";
	print("unary_expression : NOT unary_expression", $$->s1);
	
}
| factor {
	$$ = $1;
	// cout << $$->b << "\n";
	print("unary_expression : factor", $$->s1);
	
}
		 ;
	
factor	: variable {
	$$ = $1;
	print("factor : variable", $$->s1);
}

| ID LPAREN argument_list RPAREN {
	$$ = new ssbTriplet();
	$$->s1 = $1->getName() + "(" + $3->s + ")";
	
	SymbolInfo *info = table->LookUp($1->getName());
	if(info == nullptr){
		$$->s2 = "u";
		printError("Undeclared function " + $1->getName());
	}
	else if(info->getFuncInfo() == nullptr){
		$$->s2 = "u";
		printError(info->getName() + " is not a function");
	}
	else{
		functionInfo *fInfo = info->getFuncInfo();
		int n = fInfo->types.size();
		bool ok = n == $3->v.size();
		if(ok){
			for(int i = 0; i < n; ++i){
				if($3->v[i].b){
					printError("Type mismatch, " + $3->v[i].s1 + " is an array");
					break;
				}
				if(fInfo->types[i] != $3->v[i].s2 && $3->v[i].s2 != "u"){
					printError( to_string(i + 1) + "th argument mismatch in function " + $1->getName());
					break;
				}

			}
		}
		else{
			printError("Total number of arguments mismatch in function " + $1->getName());
		}
		$$->s2 = fInfo->returnType;
	}
}

| LPAREN expression RPAREN {
	$$ = $2;
	$$->s1 = "(" + $2->s1 + ")";
	print("factor : LPAREN expression RPAREN", $$->s1);
}

| CONST_INT {
	$$ = new ssbTriplet();
	$$->s1 = $1->getName();
	$$->s2 = "int";
	// 							DELETE const?
	print("factor : CONST_INT", $$->s1);

}

| CONST_FLOAT {
	$$ = new ssbTriplet();
	$$->s1 = $1->getName();
	$$->s2 = "float";
	print("factor : CONST_FLOAT", $$->s1);

}
| variable INCOP {
	if($1->b){
		printArrayError($1->s1);
	}
	// else if($1->s2 == "void"){
	// 	printVoidError($1->s1);
	// }
	//  											FURTHER WORK?
	$$ = $1;
	$$->s1 += "++";
	//  								IS IT OKAY TO CHANGE B
	$$->b = false;

	print("factor : variable INCOP", $$->s1);
}

| variable DECOP{
	if($1->b){
		printArrayError($1->s1);
	}
	//  											FURTHER WORK?
	// else if($1->s2 == "void"){
	// 	printVoidError($1->s1);
	// }
	$$ = $1;
	$$->s1 += "--";
	//  								IS IT OKAY TO CHANGE B
	$$->b = false;
	print("factor : variable DECOP", $$->s1);
}
;
	
argument_list : arguments {
	$$ = $1;
	print("argument_list : arguments", $$->s);
}
| {
	$$ = new vssbsPair();
	print("argument_list : ", $$->s);

}
;
	
arguments : arguments COMMA logic_expression {
	$1->v.push_back(*$3);
	$1->s+= ","+ $3->s1;
	$$ = $1;
	delete $3;
	print("arguments : arguments COMMA logic_expression ", $$->s);
}
| logic_expression {
	$$ = new vssbsPair();
	$$->s = $1->s1;
	$$->v.push_back(*$1);
	delete $1;
	print("arguments : logic_expression ", $$->s);
}
;
 
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
    yyparse();


	table->PrintAllScopeTable(log);

	log << "\n\nTotal lines: " << yylineno << "\nTotal errors: " << errorCount; 
    return 0;
    
}
