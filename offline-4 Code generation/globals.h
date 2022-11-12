#ifndef GLOBALS
#define GLOBALS 1

#include <utility>
#include <string>
#include <vector>
#include "symboltable.h"
#include <set>
#include <list>
#include <map>
#include <iterator>
using namespace std;

typedef pair<string, string> pss;
struct ListPos{
    list<string>::iterator start, end;
};


struct vsPair{
	vector<string> v;
	string s;
		
};

struct isPair{
    SymbolInfo *info;
    string s;
};

struct ssPair{
    string s1;
    string s2;
};

struct vsbTriplet{
    vector<string> v;
    string s;
    bool b = false;
};

struct vbsPair{
    vector<pair<string, int>> v;
    string s;
};
struct vssPair{
    vector<pair<string,string>> v;
    string s;
};


struct ssbTriplet{
    string s1;
    string s2;
    bool b = false;
    SymbolInfo *info;
    string reg;
    int stackPos;
    string label;
};

struct vssbsPair{
    vector<ssbTriplet> v;
    string s;
};


struct varInfo{
    bool global;
    int stackPos;
    string name;
};

struct strPos{
    string *s;
};

struct sssTriplet{
    string s1, s2, s3;
};

extern SymbolTable *table;
extern ofstream log;
extern int errorCount;
extern ofstream error;
extern int errorCount;
extern string gap;
#endif