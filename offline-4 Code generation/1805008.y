%{
    #include "globals.h"
	#include <fstream>
	#include <stack>
	#include <map>
	#include <iterator>
	#include <sstream>

	extern int yylineno;
	SymbolTable* table = new SymbolTable(30);
	using namespace std;

	typedef list<string>::iterator lIter;

	int errorCount = 0;

	ofstream log("log.txt");
	ofstream error("error.txt");

    int yyparse(void);
    int yylex(void);
    extern FILE *yyin;

	string gap;

	void printError(string s1){
		cout << "Error at line " << yylineno << ": " << s1 << "\n\n";
        remove("code.asm");
		exit(0);
	}
	void printError(string s1, int lineNo){
		cout << "Error at line " << lineNo << ": " << s1 << "\n\n";
        remove("code.asm");
		exit(0);
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

	stack<string> returnTypesStack;

	int funcDefStart = 0;

	string currFuncReturnType;
	string currFuncName;

	map<string, bool> regMap;

	int sp = 0;


	map<string,varInfo> varPosition;

	string freeReg(){
		if(regMap["AX"]){
			regMap["AX"] = false;
			return "AX";
		}
		if(regMap["BX"]){
			regMap["BX"] = false;
			return "BX";
		}
		if(regMap["CX"]){
			regMap["CX"] = false;
			return "CX";
		}
		if(regMap["DX"]){
			regMap["DX"] = false;
			return "DX";
		}
		
		cout << yylineno << "\n";
		cout << "---------------------------------------------------------------------";
		return "KX";
	}

	vector<SymbolInfo*> globalVars;

	int labelCount = 0;
	string getLabel(){
		++labelCount;
		return "label" + to_string(labelCount);
	}
	map<string, string> relJump;
	map<string, string> logMap;
	map<string, int> spInc;

	string getOffset(SymbolInfo *info){
		return "+" + to_string(varPosition[info->getName()+"-"+info->scopeId].stackPos - sp);
	}

	// SymbolInfo *info;
	int c = 0;

	ofstream codeFile;

	void codeOut(string code){
		stringstream ss(code);
		string line;
		string codeWithGap;
		while(getline(ss, line, '\n')){
			if(line == ".CODE" || line.substr(0, 5) == "label" || line.substr(0, 4) == "PROC"){
				codeWithGap += line + "\n";
			}
			else
				codeWithGap += gap + line + "\n";
		}

		codeFile << codeWithGap; 
	}
	bool dataSeg, codeSeg;
	ofstream optCode("codeOptimized.asm");

	bool isGlobal(SymbolInfo *info){
		return varPosition[info->getName()+"-"+info->scopeId].global;
	}

	bool split(string line, string &op, string &reg1, string &reg2){
		int j = -1,k = 0;
		op.clear();
		reg1.clear();
		reg2.clear();
		bool blank = true;
		line = line + " ";
		for(int i = 0 ; i < line.size(); ++i){
			if(isspace(line[i])){

			}
			else if(line[i] == ';'){
				return false;
			}
			else{
				break;
			}
		}
		vector<string> strings(6);
		for(int i = 0; i < line.size(); ++i){

			if(line[i] == ' ' || line[i] == ',' ||  line[i] == '\t'){
				if(j == -1)
					continue;
				int len = i - j;
				strings[k++] = line.substr(j, len);
				blank = false;
				j = -1;
			}
			else{
				if(j == -1){
					j = i;
				}
			}
		}
		op = strings[0];
		if((op == "ADD" || op == "SUB") && strings[1] == "WORD"){
			reg1 = strings[3];
			reg2 = strings[4];
		}
		else{
			reg1 = strings[1];
			reg2 = strings[2];
		}

		return blank;
	}
	int windowSize = 500;
	int currWindowSize = 0;

	bool getValidStart(ifstream &in, string &line, string &op, string &reg1, string &reg2){
		while(getline(in, line)){
			split(line, op, reg1, reg2);
			// if(op.size()){
			// 	optCode << line << "\n";
			// }
			if(op.size() == 0 || op == "PROC" || op == "END" || reg1 == "ENDP" || (op.size() > 4)){
				if(op.size())
					optCode << line << "\n";
				continue;
			}
			return true;
		}
		return false;
	}

	bool getNextInsideBlock(ifstream &in, string &line, string &op, string &reg1, string &reg2){
		if(currWindowSize == windowSize){
			currWindowSize = 0;
			return false;
		}
		while(getline(in, line)){
			split(line, op, reg1, reg2);
			if(op.size() == 0)
				continue;
			if(op == "PROC" || op == "END" || reg1 == "ENDP" || op.size() > 3){
				optCode << line << "\n";
				return false;
			}
			++currWindowSize;
			return true;
		}
		return false;
	}

	void peepholeOptimization(){
		ifstream code("code.asm");

		string line, op, reg1, reg2;
		// while(getline(code, line)){
		// 	split(line, op, reg1, reg2);
		// 	if(op.size())
		// 		optCode << line << "\n";
		// 	if(op == ".CODE")
		// 		break;
		// }


		set<string> changed;
		map<string, string> mov;
		bool ret = false;
		bool ch4 = false;


		while(true){

			if(!getNextInsideBlock(code, line, op, reg1, reg2)){
				changed.clear();
				mov.clear();
				ret = false;
				ch4 = false;
				currWindowSize = 0;

				if(!getValidStart(code, line, op, reg1, reg2)){
					return;
				}
			}
			if(ret){
				continue;
			}
			if(op == "PUSH" || op == "POP"){
				changed.insert("SP");
			}
			else if(op == "MOV"){
				if(reg1 == reg2){
					continue;
				}
				if(mov.find(reg1) == mov.end()){
					mov[reg1] = reg2;
					optCode << line << "\n";
				}
				else if(
					(mov[reg1] == reg2 && changed.find(reg1) == changed.end() && changed.find(reg2) == changed.end() && (mov.find(reg2) == mov.end() || mov[reg2] == reg1))
					||
					(mov.find(reg2) != mov.end() && mov[reg2] == reg1 && changed.find(reg1) == changed.end() && changed.find(reg2) == changed.end() && (mov.find(reg1) == mov.end() || mov[reg1] == reg2))
				){
					// cout << reg1 << " " << reg2 << "\n";
					// for(auto v : changed){
					// 	cout << "set content:  " << v << "\n";
					// }
					if((reg1[0] == '[' && changed.find(reg1.substr(1,2)) == changed.end() ) || (reg2[0] == '[' && changed.find(reg2.substr(1,2)) == changed.end())){
						continue;
					}
					else if(reg1[0] != '[' && reg2[0] != '[')
						continue;
					
					optCode << line << "\n";

				}
				else{
					optCode << line << "\n";
					mov[reg1] = reg2;
				}

				if(reg1 == "AH" && reg2 == "4CH"){
					ch4 = true;
				}
			}
			else if(op == "RET" || (op == "INT" && reg1 == "21H"  && ch4 ) ){

				ret = true;
			}
			else{
				// if(op == "SUB"){
				// 	cout << reg1 << " asd " << reg2 << "\n";
				// }
				if(reg1.size()){
					changed.insert(reg1);
				}
			}

			if(op != "MOV"){
				optCode << line << "\n";
			}

		}

		code.close();
		optCode.close();

	}

	void makeComment(string &code){
		// string code(*code1);
		string comment = ";";
		int n = code.size();
		for(int i = 0; i < n; ++i){
			comment += code[i];
			if(code[i] == '\n'){
				comment += ";";
			}
		}
		codeOut(comment);
	}
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
	strPos *sps;
	sssTriplet *sss;
}


%token <info> IF ELSE FOR WHILE  ADDOP MULOP ASSIGNOP RELOP LOGICOP NOT INT FLOAT RETURN VOID PRINTLN SEMICOLON COMMA LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD INCOP DECOP CONST_INT CONST_FLOAT ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%type <vbs> declaration_list  
%type <vss> parameter_list 
%type <s> type_specifier func_declaration var_declaration unit  func_definition program start 
%type <ssb> variable factor unary_expression term simple_expression rel_expression logic_expression expression expression_statement IF_COMM
%type <vssbs> arguments argument_list
%type <sps> statement statements compound_statement

%%


start : program {
	$$ = $1;
	delete $$;
}
;

program : program unit  {
	$$ = new string(*$1 + "\n" +  *$2 );
	delete $1;
	delete $2;
}

| unit {
	$$ = $1;
}
| program error {
	$$ = $1;
	cout << "Here";

} 
| error {
	$$ = new string();
}

;
	
unit : var_declaration {

}
| func_declaration {

}
| func_definition {
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
	delete $1;
	delete $2;
	delete $4;
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
	delete $1;
	delete $2;
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
	int c = 0;
	for(auto ss : $4->v){
		if(ss.second.size() == 0){
			printError( to_string(i + 1) + "th parameter's name not given in function definition of " + $2->getName());
		}
		else{
			SymbolInfo *info = new SymbolInfo(ss.second, "ID", ss.first);
			bool t2 = table->Insert(info);
			varPosition[info->getName() + "-" + info->scopeId] = {false, sp - 2,info->getName()};
			c += 2;
			sp -= 2;
			if(!t2){
				printError("multiple declaration of " + info->getName() + " in parameter");
				delete info;
			
			}	
		}
		++i;
	}
	returnTypesStack.push(*$1);
	currFuncReturnType = *$1;
	currFuncName = $2->getName();
	table->stackInc(c);
	string code = "PROC " + $2->getName() + "\n";
	if($2->getName() == "main" && dataSeg){
		code += "MOV AX, @DATA\nMOV DS, AX\n";
	}
	code += "SUB SP, " + to_string(c) + "\n";
	if(!codeSeg){
		code = "\n\n.CODE\n" + code;
		codeSeg = true;
	}
	codeOut(code);

} compound_statement {
	$$ = new string(*$1 + " " + $2->getName() + "(" + $4->s + ")" + *($7->s) );
	returnTypesStack.pop();
	if($2->getName() == "main"){
		codeOut("    MOV AH, 4CH\n    INT 21H\n");
	}
	codeOut("RET\n" + $2->getName() + " ENDP\n");
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
	returnTypesStack.push(*$1);
	currFuncReturnType = *$1;
	currFuncName = $2->getName();
	string code = "PROC " + $2->getName() + "\n";
	if($2->getName() == "main" && dataSeg){
		code += "MOV AX, @DATA\nMOV DS, AX\n";
	}
	if(!codeSeg){
		code = "\n\n.CODE\n" + code;
		codeSeg = true;
	}
	codeOut(code);

} compound_statement {
	$$ = new string(*$1 + " " + $2->getName() + "()" + *($6->s));
	vector<string> t;
	functionInfo *f = new functionInfo(t,*$1);
	SymbolInfo *info = new SymbolInfo($2->getName(), "ID", *$1, nullptr, f);
	bool t2 = table->Insert(info);
	
	returnTypesStack.pop();
	if($2->getName() == "main"){
		codeOut("    MOV AH, 4CH\n    INT 21H\n");
	}
	codeOut($2->getName() + " ENDP\n");
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
}
| parameter_list COMMA type_specifier {
	$1->v.push_back({*$3, ""});
	$1->s += "," + *$3;
	$$ = $1;
	delete $3;
}

| type_specifier ID {
	$$ = new vssPair();
	$$->v.push_back({*$1, $2->getName()});
	$$->s = *$1 + " ";
	$$->s += $2->getName();
	delete $1;
	delete $2;
}
| type_specifier {
	$$ = new vssPair();
	$$->v.push_back({*$1, ""});
	$$->s = *$1;
	delete $1;
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
	$$ = new strPos();
	$$->s = new string("{\n" + *($2->s) + "\n}");
	string code = "ADD SP, " + to_string(table->getStackInc()) + "\n";
	sp += table->getStackInc();
	codeOut(code);
    table->ExitScope(log);
	gap = gap.erase(gap.size() - 4);
	delete $2;
}
| LCURL RCURL {
	$$ = new strPos();
	$$->s = new string("{\n\n}");
    table->ExitScope(log);

}
;
 		    
var_declaration : type_specifier declaration_list SEMICOLON {
	$$ = new string(*$1 + " " + $2->s + ";");
	int t = 0;
	string code;
	if(*$1 == "void"){
		printError("Variable type cannot be void");
	}
	else{
		for(auto s : $2->v){
			SymbolInfo *info = new SymbolInfo(s.first, "ID", *$1,s.second);
			bool t2 = table->Insert(info);
			if(!t2){
				printError("Multiple declaration of " + s.first);
				delete info;
			}

			if(info->scopeId == "1"){
				varPosition[info->getName() + "-1"] = {true, 0,info->getName()};
				if(info->isArray_()){
					code += info->getName() + " DW " + to_string(s.second) + " DUP (?)\n";
				}
				else
					code += info->getName() + " DW ?\n";

			}
			else{
				int dec = 2;
				if(s.second){
					dec = 2 * s.second;
				}
				varPosition[info->getName() + "-" + info->scopeId] = {false, sp - dec,info->getName()};
				sp -= dec;
				t += dec;
			}

		}
		if(table->currScopeId() != "1"){
			code = "SUB SP, " + to_string(t) + "\n";
		}
		else if(!dataSeg){
			dataSeg = true;
			code = ".DATA\n" + code;
		}
		table->stackInc(t);
	}
	
	codeOut(code);
	delete $1;
	delete $2;
}
;
 		 
type_specifier	: INT {
	$$ = new string($1->getName());
	delete $1;
}
|FLOAT { 
	$$ = new string($1->getName());
	printError("float not supported");
	delete $1;
}
|VOID { 
	$$ = new string($1->getName());
	delete $1;
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
}
| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
	$1->v.push_back({$3->getName(), stoi($5->getName())});
	if($1->s.size())
		$1->s += "," + $3->getName() + "[" + $5->getName() + "]";
	else
		$1->s +=  $3->getName() + "[" + $5->getName() + "]";
	$$ = $1;
}
| ID {
	$$ = new vbsPair();
	$$->v.push_back({$1->getName(), false});
	$$->s = $1->getName();

	delete $1;
}
| ID LTHIRD CONST_INT RTHIRD {
	$$ = new vbsPair();
	$$->v.push_back({$1->getName(), stoi($3->getName())});
	$$->s = $1->getName() + "[" + $3->getName()+"]";

	delete $1;
}
| declaration_list error {
	$$ = $1;
}
| error {
	$$ = new vbsPair();
}
;
 		  
statements : statement {
}
| statements statement {
	$$ = new strPos();
	$$->s = new string( *($1->s) + "\n" + *($2->s));

	delete $1;
	delete $2;
}
| statements error {
	$$ = $1;
}   
| error {
	$$ = new strPos();
}

	   ;

	   
statement : var_declaration {
	$$ = new strPos();
	$$->s = $1;
	makeComment(*$$->s);
}

| expression_statement {
	$$ = new strPos();
	$$->s = new string($1->s1);
	// makeComment(*$$->s);
	delete $1;

}
| compound_statement {
	$$ = $1;
	makeComment(*$$->s);
}
| FOR LPAREN expression_statement {
	string label = getLabel();
	codeOut(label + ":\n");
	$<s>$ = new string(label);
} expression_statement {
	string exitLabel = getLabel();
	string stLabel = getLabel();
	string expLabel = getLabel();
	codeOut("CMP " + $5->reg + ", 0\nJE " + exitLabel + "\nJMP " + stLabel + "\n" + expLabel + ":\n");
	$<sss>$ = new sssTriplet({exitLabel, stLabel, expLabel});
	
} expression {
	codeOut("JMP " + *$<s>4 + "\n" + $<sss>6->s2 + ":\n");
	regMap[$7->reg] = true;
} RPAREN  statement {
	$$ = new strPos();
	strPos* stt = $10;
	$$->s = new string("for("+$3->s1+$5->s1+$7->s1+")"+*(stt->s));
	
	string startLabel = getLabel();
	string endLabel = getLabel();

	codeOut("JMP " + $<sss>6->s3 + "\n" + $<sss>6->s1 + ":\n");
	makeComment(*$$->s);
	delete $3;
	delete $5;
	delete $7;
	delete stt;
}
| IF_COMM  %prec LOWER_THAN_ELSE {
	$$ = new strPos();
	$$->s = new string($1->s1);
	string label = getLabel();
	codeOut($1->label + ":\n");
	makeComment(*$$->s);
	delete $1;
}

| IF_COMM ELSE statement {
	$$ = new strPos();
	$$->s = new string($1->s1 + "\nelse " + *$3->s);
	codeOut($1->label + ":\n");
	makeComment(*$$->s);

}
| WHILE LPAREN{
	string label = getLabel();
	codeOut(label + ":\n");
	$<s>$ = new string(label);

} expression{
	string label = getLabel();
	string code = "CMP " + $4->reg + ", 0\nJE " + label + "\n";
	codeOut(code);
	$<s>$ = new string(label);
	regMap[$4->reg] = true;
} RPAREN statement {
	$$ = new strPos();
	ssbTriplet *exp = $4;
	strPos *st = $7;
	$$->s = new string("while (" + exp->s1 + ")" + *(st->s));


	string startLabel = getLabel();
	string endLabel = getLabel();


	codeOut("JMP " + *$<s>3 + "\n" + *$<s>5 + ":\n");
	makeComment(*$$->s);
	delete exp;
	delete st;	

}
| PRINTLN LPAREN ID RPAREN SEMICOLON {
	$$ = new strPos();
	$$->s = new string("printf(" + $3->getName() + ");");
	SymbolInfo *info = table->LookUp($3->getName()) ;
	if(info == nullptr){
		printError("undeclared variable " + $3->getName());
	}
	if(info){
		string code;
		string reg = freeReg();
		string offset = getOffset(info);
		if(isGlobal(info)){
			code = "MOV " + reg + ", " + $3->getName() + "\n";
		}
		else{
			code = "MOV BP, SP\nMOV " + reg + ", [BP" + offset + "]\n";
		}
		code += "MOV BP, SP\nMOV [BP-4], " + reg + "\nCALL PRINT_NUMBER\n";

		regMap[reg] = true;
		codeOut(code);
	}
	makeComment(*$$->s);
	delete $3;

}
| RETURN expression SEMICOLON {
	$$ = new strPos();
	$$->s = new string("return " + $2->s1 + ";");
	if($2->b || ($2->s2 != "u" && $2->s2 != returnTypesStack.top())){
		if($2->s2 == "int" && returnTypesStack.top() == "float"){

		}
		else
			printError("Return type mismatch");
	}
	string code;
	if(currFuncName == "main"){
		code = "    MOV AH, 4CH\n    INT 21H\n";
	}
	else{
		code = "ADD SP, " + to_string(-sp)  + "\nMOV BP, SP\nMOV [BP + 2], " + $2->reg + "\nRET\n";
	}
	regMap[$2->reg] = true;
	delete $2;
	codeOut(code);
	makeComment(*$$->s);
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
	returnTypesStack.push(*$1);
	currFuncReturnType = *$1;
	currFuncName = $2->getName();

} compound_statement {
	$$ = new strPos();
	$$->s = new string(*$1 + " " + $2->getName() + "(" + $4->s + ")" + *($7->s) );
	returnTypesStack.pop();

	delete $1;
	delete $2;
	delete $4;
	delete $7;

}

| type_specifier ID LPAREN RPAREN {
	printError("invalid scope for defining function " + $2->getName());
	returnTypesStack.push(*$1);
	currFuncReturnType = *$1;
	currFuncName = $2->getName();

} compound_statement {
	$$ = new strPos();
	$$->s = new string(*$1 + " " + $2->getName() + "()" + *($6->s) );
	returnTypesStack.pop();
	delete $1;
	delete $2;
	delete $6;
}
| type_specifier ID LPAREN parameter_list RPAREN SEMICOLON {
	$$ = new strPos();
	$$->s = new string(*$1 + " " + $2->getName() + "(" + $4->s+");" );
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
	$$ = new strPos();
	$$->s = new string(*$1 + " " + $2->getName() + "();");
	printError("Invalid scope for declaring function " + $2->getName());
	delete $1;
	delete $2;
}
;
	  
IF_COMM : IF LPAREN expression {
	string label = getLabel();
	string code = "CMP " + $3->reg + ", 0\nJE " + label + "\n"; 
	$<s>$ = new string(label);
	codeOut(code);
	regMap[$3->reg] = true;

} RPAREN statement {
	string label = getLabel();
	$$ = new ssbTriplet();
	string code = "JMP " + label + "\n" + *$<s>4 + ":\n";
	$$->label = label;
	$$->s1 = "if(" + $3->s1 + ")" + *$6->s;
	delete $<s>4;
	delete $3;
	delete $6;
	codeOut(code);
}
;



expression_statement 	: SEMICOLON	{
	$$ = new ssbTriplet();
	$$->s1 = ";";

	$$->reg = "";
}		
| expression SEMICOLON {
	$$ = $1;
	$$->s1 += ";";
	regMap[$1->reg] = true;	

} 

			;
	  
variable : ID {
	SymbolInfo *info;
	$$ = new ssbTriplet();
	$$->s1 = $1->getName();
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
	}
	$$->info = info;
	delete $1;

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
	$$->info = info;
	$$->reg = $3->reg;
} 
	 ;

	 
expression : logic_expression {
	$$ = $1;
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


	string code;

	if($1->info->isArray_()){
		string offset =  getOffset($1->info);
		if(isGlobal($1->info)){
			code = "SHL " + $1->reg + ", 1\n" + 
					"LEA SI," + $1->info->getName() + "\n" +
					"ADD SI, " + $1->reg + "\n" + 
					"MOV [SI], " + $3->reg + "\n";
		}
		else{
			code = 
				"SHL " + $1->reg + ", 1\n" + 
				"MOV BP, SP\n" +
				"ADD BP, " + $1->reg + "\n" + 
				"MOV [BP" + offset + "], " + $3->reg + "\n";
		}	
		regMap[$1->reg] = true;
		
	}
	else{

		if(isGlobal($1->info)){
			code = "MOV " + $1->info->getName() + ", " + $3->reg + "\n";
		}
		else{
			string offset = getOffset($1->info);
			code = "MOV BP, SP\nMOV [BP" + offset + "], " + $3->reg + "\n";
		}
	}
	regMap[$1->reg] = true;
	$$->reg = $3->reg;
	delete $3;
	codeOut(code);
	makeComment($$->s1);

}
	   ;
			
logic_expression : rel_expression 	{
	$$ = $1;
	
}
| rel_expression LOGICOP {
	string label = getLabel();
	// codeOut(label + ":\n");
	$<s>$ = new string(label);
	string code;
	if($2->getName() == "||"){
		code = "CMP " + $1->reg + ", 0\n" + 
					  "JNE " + label + "\n";
	}
	else{
		code = "CMP " + $1->reg + ", 0\n" + 
					  "JE " + label + "\n";
	}
	codeOut(code);
	regMap[$1->reg] = true;
} rel_expression {
	
	$$ = $1;
	$$->s1 += $2->getName() + $4->s1;

	if($1->s2 == "void" || $4->s2 == "void"){
		printVoidError();
		$1->s2 = "u";
	}
	else if($1->s2 == "u" || $4->s2 == "u"){
		$1->s2 = "u";
	}
	else
		$$->s2 = "int";

	string label = getLabel();
	string code;
	if($2->getName() == "||"){
		code = "CMP " + $4->reg + ", 0\n" + 
					  "JNE " + *$<s>3 + "\n"+
					  "MOV " + $1->reg + ",0\n" + 
					  "JMP " + label + "\n" + 
					  *$<s>3 + ":\n" + 
					  "MOV " + $1->reg + ",1\n" + 
					  label + ":\n"
					  ;
	
	}
	else{
		code = "CMP " + $4->reg + ", 0\n" + 
					  "JE " + *$<s>3 + "\n"+
					  "MOV " + $1->reg + ",1\n" + 
					  "JMP " + label + "\n" + 
					  *$<s>3 + ":\n" + 
					  "MOV " + $1->reg + ",0\n" + 
					  label + ":\n"
					  ;
	}


	// string label = getLabel();
	// string code = logMap[$2->getName()] + " " + $1->reg + ", " + $3->reg + "\n"+
	// 				"CMP " + $1->reg + ", 0\n" + 
	// 				"JE " + label + "\n" + 
	// 				"MOV " + $1->reg + ", 1\n" + 
	// 				label + ":\n";
	
	regMap[$4->reg] = true;
	$$->reg = $1->reg;

	delete $4;
	codeOut(code);
	makeComment($$->s1);

}
;
			
rel_expression	: simple_expression {
	
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

	string label = getLabel();
	string reg = freeReg();
	string code = "MOV " + reg + ", 1\n"+
				"CMP " + $1->reg + ", " + $3->reg + "\n" +
				relJump[$2->getName()] + " " + label + "\n" + 
				"XOR " + reg + ", " + reg + "\n" +  
				label + ":\n";
	regMap[$1->reg] = true;
	regMap[$3->reg] = true;

	$$->reg = reg;

	delete $3;
	codeOut(code);
	makeComment($$->s1);

}
		;
				
simple_expression : term {
	
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

	string op = "ADD";
	if($2->getName() == "-")
		op = "SUB";

	string code = op + " " + $1->reg + ", " + $3->reg + "\n";
	regMap[$3->reg] = true;
	$$->reg = $1->reg;


	delete $3;
	codeOut(code);
	makeComment($$->s1);

} 
		  ;
					
term :	unary_expression {
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


	string ar, br, code;

	if($2->getName() == "*"){

		if($1->reg == "AX"){
			ar = "AX";
			br = $3->reg;
		}
		else if($3->reg == "AX"){
			ar = "AX";
			br = $1->reg;
		}
		if(ar == "AX"){
			code = "MUL " + br + "\n";
			regMap[br] = true;
			$$->reg = ar;
		}
		else{
			if(!regMap["AX"]){
				code = "PUSH AX\n";
			}
			code += "MOV AX, " + $1->reg + "\n" + 
					"MUL " + $3->reg + "\n";
			if(!regMap["AX"]){
				code += "MOV " + $1->reg + ", AX\n" + 
				"POP AX\n";
				$$->reg = $1->reg;
				regMap[$3->reg] = true;
			}
			else{
				regMap["AX"] = false;
				regMap[$1->reg] = true;
				regMap[$3->reg] = true;
				$$->reg = "AX";
			}
		}

	}
	else{
		ar = $1->reg;
		br = $3->reg;
		// string reg = freeReg();
		// if(ar == "DX" || br == "DX"){
		// 	code = "MOV " + reg + ", DX\n";
		// 	if(ar == "DX")
		// 		ar = reg;
		// 	else
		// 		br = reg;
		// }
		// else if(!regMap["DX"]){
		// 	code += "PUSH DX\n";
		// }
		// code += "XOR DX, DX\n";
		string push, pop;
		string regs[3] = {"AX", "BX", "DX"};
		for(string t : regs){
			if(ar != t && br != t && !regMap[t]){
				push += "PUSH " + t + "\n";
				pop = "POP " + t +" \n" + pop;
			}
		}
		string label = getLabel();
		code = "MOV AX, "+ ar +"\nMOV BX, " + br + "\nXOR DX, DX\nCMP AX, 0\nJGE " + label + "\nMOV DX,0xFFFF\n" + label + ":\n IDIV BX\n";
		string res = "AX";
		if($2->getName() == "%")
			res = "DX";
		if($1->reg == res){
			regMap[$3->reg] = true;
			$$->reg = res;
		}
		else if($3->reg == res){
			regMap[$1->reg] = true;
			$$->reg = res;
		}
		else {
			regMap[$1->reg] = true;
			regMap[$3->reg] = true;
			if(!regMap[res]){
				$$->reg = freeReg();
				code += "MOV " + $$->reg +"," + res + "\n"; 
			}
			else{
				regMap[res] = false;
				$$->reg = res;
			}
		}
		code = push + code + pop;
	}

	delete $3;	
	codeOut(code);
	makeComment($$->s1);
	
}
     ;


unary_expression : ADDOP unary_expression  {
	
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

	if($1->getName() == "-"){
		codeOut("NEG " + $2->reg + "\n");
		makeComment($$->s1);

	}

	delete $1;

	
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
	string label1 = getLabel();
	string label2 = getLabel();

	string code = "CMP " + $2->reg + ", 0\n" +
			 "JE "+ label1 + "\n" +
			"MOV " + $2->reg + ", 1\n" +
			"JMP " + label2 + "\n" +
			label1 + ":\n" +
			"MOV " + $2->reg + ", 0\n" +
			label2 + ":\n"
			;
	codeOut(code);
	makeComment($$->s1);

}
| factor {
}
		 ;
	
factor	: variable {
	$$ = $1;

	string reg;
	string code;

	if($1->info->isArray_()){
		string offset =  getOffset($1->info);

		if(isGlobal($1->info)){
			code = "SHL " + $1->reg + ", 1\n" + 
					"LEA SI," + $1->info->getName() + "\n" +
					"ADD SI, " + $1->reg + "\n" + 
					"MOV " + $1->reg + ",[SI]\n";
		}
		else{
			code = 
				"SHL " + $1->reg + ", 1\n" + 
				"MOV BP, SP\n" +
				"ADD BP, " + $1->reg + "\n" + 
				"MOV " + $1->reg + ", [BP" + offset + "]\n";
		}// regMap[$1->reg] = true;
		reg = $1->reg;
		
	}
	else{
		reg = freeReg();
		string offset =  getOffset($1->info);
		if(isGlobal($1->info)){
			code = "MOV " + reg + ", " + $1->info->getName() + "\n";
		}
		else
			code = "MOV BP, SP\nMOV " + reg + ", [BP" +  offset + "]\n";
	}
	$$->reg = reg;
	
	codeOut(code);
	makeComment($$->s1);

}

| ID LPAREN {
	// info = table->LookUp($1->getName());
} argument_list RPAREN {
	$$ = new ssbTriplet();
	$$->s1 = $1->getName() + "(" + $4->s + ")";
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
		bool ok = n == $4->v.size();
		if(ok){
			for(int i = 0; i < n; ++i){
				if($4->v[i].b){
					printError("Type mismatch, " + $4->v[i].s1 + " is an array");
					break;
				}
				if(fInfo->types[i] != $4->v[i].s2 && $4->v[i].s2 != "u"){
					if(fInfo->types[i] == "float" && $4->v[i].s2 == "int")
						;
					else{
						printError( to_string(i + 1) + "th argument mismatch in function " + $1->getName());
						break;
					}
				}

			}
		}
		else{
			printError("Total number of arguments mismatch in function " + $1->getName());
		}
		$$->s2 = fInfo->returnType;
	}
	string regs[] = {"AX", "BX", "CX", "DX"};
	string reg = freeReg();	
	string code = "PUSH DX\nPUSH CX\nPUSH BX\nPUSH AX\nSUB SP, 2\nCALL " +
		info->getName() + "\nPOP " + reg + "\n";
	for(string s : regs){
		if(s != reg){
			code += "POP " + s + "\n";
		}
		else{
			code += "ADD SP, 2\n";
		}
	}
	$$->reg = reg;
	codeOut(code);
	makeComment($$->s1);

}

| LPAREN expression RPAREN {
	$$ = $2;
	$$->s1 = "(" + $2->s1 + ")";
}

| CONST_INT {
	$$ = new ssbTriplet();
	$$->s1 = $1->getName();
	$$->s2 = "int";

	string code;

	string reg = freeReg();
	code = "MOV " + reg + ", " + $1->getName() + "\n";

	$$->reg = reg;
	codeOut(code);
}

| CONST_FLOAT {
	$$ = new ssbTriplet();
	$$->s1 = $1->getName();
	$$->s2 = "float";

}
| variable INCOP {
	if($1->b){
		printArrayError($1->s1);
	}
	$$ = $1;
	$$->s1 += "++";
	//  								IS IT OKAY TO CHANGE B
	$$->b = false;

	string reg = freeReg();
	string code;

	if($1->info->isArray_()){
		string offset =  getOffset($1->info);

		if(isGlobal($1->info)){
			code = "SHL " + $1->reg + ", 1\n" + 
					"LEA SI," + $1->info->getName() + "\n" +
					"ADD SI, " + $1->reg + "\n" + 
					"MOV " + reg +",[SI]\n" +
					"ADD WORD PTR [SI], 1\n" ;
		}
		else
			code = 
				"SHL " + $1->reg + ", 1\n" + 
				"MOV BP, SP\n" +
				"ADD BP, " + $1->reg + "\n" + 
				"MOV " + reg + ", [BP" + offset + "]\n" + 
				"ADD WORD PTR [BP" + offset +  "], 1\n";

			// "ADD WORD PTR [BP" + offset +  "], 1\n";
		regMap[$1->reg] = true;
		
	}
	else{
		string offset =  getOffset($1->info);
		if(isGlobal($1->info)){
			code = "MOV " + reg + ", " + $1->info->getName() + "\nINC " + $1->info->getName() + "\n";
		}
		else{
			code = 
					"MOV BP, SP\nMOV " + reg + ", [BP" + offset + "]\n" +
					"ADD WORD PTR [BP" + offset + "], 1\n";
		}
	}
	$$->reg = reg;
	codeOut(code);
	makeComment($$->s1);

}

| variable DECOP{
	if($1->b){
		printArrayError($1->s1);
	}
	$$ = $1;
	$$->s1 += "--";
	$$->b = false;

	string reg = freeReg();
	string code;

	if($1->info->isArray_()){
		string offset = getOffset($1->info);

		if(isGlobal($1->info)){
			code = "SHL " + $1->reg + ", 1\n" + 
					"LEA SI," + $1->info->getName() + "\n" +
					"ADD SI, " + $1->reg + "\n" + 
					"MOV " + reg +",[SI]\nSUB WORD PTR [SI], 1\n" 
					;
		}
		else
			code = 
				"SHL " + $1->reg + ", 1\n" + 
				"MOV BP, SP\n" +
				"ADD BP, " + $1->reg + "\n" + 
				"MOV " + reg + ", [BP" + offset + "]\n" + 
				"SUB WORD PTR [BP" + offset +  "], 1\n";
		regMap[$1->reg] = true;
		
	}
	else{
		string offset = getOffset($1->info);
		if(isGlobal($1->info)){
			code = "MOV " + reg + ", " + $1->info->getName() + "\nSUB " + $1->info->getName() + "\n";
		}
		else{
			code = 
					"MOV BP, SP\nMOV " + reg + ", [BP" +  offset + "]\nSUB WORD PTR [BP" + offset + "], 1\n";
		}
	}
	$$->reg = reg;
	codeOut(code);
	makeComment($$->s1);

}
;
	
argument_list : arguments {
}
| {
	$$ = new vssbsPair();
}
;
	
arguments : arguments COMMA logic_expression {
	$1->v.push_back(*$3);
	$1->s+= ","+ $3->s1;
	$$ = $1;
	++c;

	string code = "MOV BP, SP\nMOV [BP- " + to_string((c + 6) * 2) + " ], " + $3->reg + "\n";
	regMap[$3->reg] = true;
	delete $3;

	codeOut(code);
	makeComment($$->s);
	
}
| logic_expression {
	$$ = new vssbsPair();
	$$->s = $1->s1;
	$$->v.push_back(*$1);
	
	c = 1;
	string code = "MOV BP, SP\nMOV [BP-14], " + $1->reg + "\n";


	regMap[$1->reg] = true;
	delete $1;

	codeOut(code);

}
;
 
%%

int main(int argc, char *argv[]){



	regMap["AX"] = true;
	regMap["BX"] = true;
	regMap["CX"] = true;
	regMap["DX"] = true;

	relJump[">"] = "JG";
	relJump[">="] = "JGE";
	relJump["<"] = "JL";
	relJump["<="] = "JLE";
	relJump["=="] = "JE";
	relJump["!="] = "JNE";

	logMap["&&"] = "AND";
	logMap["||"] = "OR";

	codeFile.open("code.asm");
	codeFile << ".MODEL SMALL\n.STACK 100H\n";
	dataSeg = false;
	codeSeg = false;

	const char *text = 
	R""""(
		
PRINT_NUMBER PROC 
	MOV BP, SP 
	MOV BX, [BP-2]
		
	PUSH DX
	PUSH AX
	PUSH CX
	
	
	MOV CX, 0
	CMP BX, 0
	JGE NOT_NEG_P_PROC
	MOV DL, '-'
	MOV AH, 2
	INT 21H
	NEG BX
												
NOT_NEG_P_PROC:
	
	XOR DX, DX
	MOV AX, BX    
	MOV BX, 10
	
	CMP AX, 0
	JNE LOOP_PRINT_NUMBER
	PUSH 0   
	ADD CX, 1
	JMP PRINT
	
LOOP_PRINT_NUMBER:        ;
			
	CMP AX, 0
	JE PRINT
	
	DIV BX      
	PUSH DX
	XOR DX, DX
	ADD CX, 1
	JMP LOOP_PRINT_NUMBER
		
PRINT:
	
	POP DX 
	ADD DL, '0'
	MOV AH, 2
	INT 21H
	SUB CX, 1 
	CMP CX, 0
	JE BREAK_LOOP
	JMP PRINT
	
BREAK_LOOP:
	
		
	POP CX
	POP AX
	POP DX
		
	MOV AH, 2
	MOV DL, 10
	INT 21H
	MOV DL, 13
	INT 21H

	RET
	
	
PRINT_NUMBER ENDP
		)"""";

	string printFunc(text);
	




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
	if(!codeSeg){
		codeOut("\n\n.CODE\n");
		codeSeg = true;
	}
	codeOut(printFunc +"\n\nEND MAIN\n");

	codeFile.close();

	peepholeOptimization();

	

    return 0;
    
}
