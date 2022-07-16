#ifndef GLOBALS
#define GLOBALS 1

#include <utility>
#include <string>
#include <vector>
#include "symboltable.h"
#include <set>
using namespace std;

typedef pair<string, string> pss;
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
    vector<pair<string, bool>> v;
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
};

struct vssbsPair{
    vector<ssbTriplet> v;
    string s;
};

extern SymbolTable *table;
extern ofstream log;
extern int errorCount;
extern ofstream error;
extern int errorCount;
#endif