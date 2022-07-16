#ifndef SYMBOL_TABLE
#define SYMBOL_TABLE 0
#include <string>
#include <fstream>
#include <iostream>
using namespace std;


class functionInfo{

public:

    vector<string> types;
    string returnType;
    bool defined;

    functionInfo(vector<string> t,string r){
        types = t;
        returnType = r;
        defined = false;
    }

    functionInfo(vector<string> t,string r, bool def){
        types = t;
        returnType = r;
        defined = def;
    }
    void print(){
        cout << types.size() << " "   << returnType << "\n"; 
    }
};

class SymbolInfo{

    string name, type;
    string dataType;
    bool isArray = false;
    SymbolInfo* next;
    functionInfo *funcInfo;

public:

    SymbolInfo(string n,string t, SymbolInfo* next){
        name = n;
        type = t;
        this->next = next;
        funcInfo = nullptr;
    }

    SymbolInfo(string n,string t): SymbolInfo(n, t, nullptr){}

    SymbolInfo(string n,string t, string u, SymbolInfo* next,functionInfo* i): SymbolInfo(n, t, nullptr){
        funcInfo = i;
        dataType = u;
    }

    SymbolInfo(string n,string t, string u){
        name = n;
        type = t;
        dataType = u;
        next = nullptr;
        funcInfo = nullptr;
    }
    SymbolInfo(string n,string t, string u, bool v){
        name = n;
        type = t;
        dataType = u;
        next = nullptr;
        funcInfo = nullptr;
        isArray = v;
    }


    string getName(){
        return name;
    }

    string getType(){
        return type;
    }

    SymbolInfo* getNext(){
        return next;
    }
    string getDataType(){
        return dataType;
    }

    functionInfo* getFuncInfo(){
        return funcInfo;
    }

    void setNext(SymbolInfo* next){
        this->next = next;
    }

    bool isArray_(){
        return isArray;
    }

    void Print(ofstream &of){
        of << "< " << name << " : " << type << " > "; 
    }
    // void Print(ofstream &of){
    //     of << "< " << name << ", " << type << ", " << dataType << ", " << (int) isArray; 
    //     if(funcInfo){
    //         of << ", " << funcInfo->types.size() << ", " << funcInfo->returnType ;  
    //     }
    //     of << " > ";
    // }
};

class ScopeTable{

    SymbolInfo* *buckets;
    int total_buckets;
    ScopeTable *parentScope;
    int childCount;
    string id;

    unsigned long sdbmhash(string key){
        unsigned long r = 0;
        int n = key.size();
        for(int i = 0; i < n; ++i){
            r = (r << 6) + (r << 16) + key[i] - r;
        }
        return r;
    }
    int calcBucketIndex(string key){
        return sdbmhash(key) % total_buckets;
    }


public:
    ScopeTable(int total_buckets, int level) : ScopeTable(total_buckets, nullptr){
        id = to_string(level);

    }

    ScopeTable(int total_buckets, ScopeTable* parent){

        this->total_buckets = total_buckets;
        buckets = new SymbolInfo*[total_buckets];
        for(int i = 0; i < total_buckets; ++i)
            buckets[i] = nullptr;
        this->parentScope = parent;
        if(parent){
            this->parentScope->childCount++;
            id = this->parentScope->id + "." + to_string(this->parentScope->childCount);
        }
        else{
            id = "1";
        }
        childCount = 0;
    }



    ~ScopeTable(){
        for(int i = 0; i < total_buckets; ++i){
            SymbolInfo *curr = buckets[i];
            while(curr){
                SymbolInfo* nxt = curr->getNext();
                delete curr;
                curr = nxt;
            }
        }
        delete[] buckets;
    }


    SymbolInfo* LookUp(string key){

        int bucketIndex = calcBucketIndex(key);
        SymbolInfo* curr = buckets[bucketIndex];
        int c = 0;

        while(curr){
            if(curr->getName() == key){

                return curr;
            }
            ++c;
            curr = curr->getNext();
        }
//        cout << "Not Found\n";
        return nullptr;
    }

    bool Insert(SymbolInfo *symbol){
        int c = 0;
        int bucketIndex = calcBucketIndex(symbol->getName());


        SymbolInfo* curr = buckets[bucketIndex];
        SymbolInfo* prev = nullptr;
        while(curr){
            if(curr->getName() == symbol->getName()){
                return false;
            }
            ++c;
            prev = curr;
            curr = curr->getNext();
        }

        if(!prev){
            buckets[bucketIndex] = symbol;
        }
        else{
            prev->setNext(symbol);
        }
        return true;

    }

    bool Delete(string key){

        int c = 0;

        int bucketIndex = calcBucketIndex(key);
        SymbolInfo* curr = buckets[bucketIndex];
        SymbolInfo* prev = nullptr;
        while(curr){
            if(curr->getName() == key){
                if(!prev){
                    buckets[bucketIndex] = curr->getNext();
                }
                else{
                    prev->setNext(curr->getNext());
                }
                delete curr;
                return true;
            }
            ++c;
            prev = curr;
            curr = curr->getNext();
        }

        return false;


    }

    ScopeTable* getParentScope(){
        return parentScope;
    }

    void Print(ofstream &of){
        of << "ScopeTable # " << id << "\n";
        for(int i = 0; i < total_buckets; ++i){
            SymbolInfo* curr = buckets[i];
            if(curr == nullptr){
                continue;
            }
            of << i << " --> ";
            while(curr){
                curr->Print(of);
                curr = curr->getNext();
            }
            of << "\n";
        }
        of << "\n";

    }

    string getId(){
        return id;
    }
};

class SymbolTable{
    ScopeTable *curr;
    int topLevelCount = 1;
    int bucketSize;
    int defaultBucketSize = 10;

public:
    SymbolTable() : SymbolTable(10){

    }

    SymbolTable(int bSize){
        curr = new ScopeTable(bSize, topLevelCount);
        bucketSize = bSize;
    }

    string EnterScope(){
        if(!curr){
            topLevelCount++;
            curr = new ScopeTable(bucketSize,topLevelCount);
        }
        else
            curr = new ScopeTable(bucketSize,curr);
        return curr->getId();
//        cout << "EnterScope " << curr << "\n";

    }

    void ExitScope(ofstream &of){
        if(curr){
            ScopeTable *parent = curr->getParentScope();
            // curr->Print(of);
            PrintAllScopeTable(of);
            delete curr;
            curr = parent;
        }
        else{
        }
    }


    bool Insert(SymbolInfo *symbol){
        if(!curr) EnterScope();
        return curr->Insert(symbol);

    }

    bool InsertInParent(SymbolInfo *symbol){
        return curr->getParentScope()->Insert(symbol);
    }

    SymbolInfo* findInParent(string key){
        return curr->getParentScope()->LookUp(key);
    }

    bool Remove(string key){
        if(!curr) return false;
        return curr->Delete(key);
    }

    SymbolInfo* LookUp(string key){
        ScopeTable* curr = this->curr;
        while(curr){
            SymbolInfo* ret = curr->LookUp(key);
            if(ret && ret->getName() == key) return ret;
            curr = curr->getParentScope();
        }
        return nullptr;
    }

    ~SymbolTable(){
        while(curr){
            ScopeTable* t = curr->getParentScope();
            delete curr;
            curr = t;
        }
    }

    void PrintCurrentScopeTable(ofstream &of){
        if(curr){
            curr->Print(of);
        }
    }

    void PrintAllScopeTable(ofstream &of){
        ScopeTable* curr = this->curr;
        of << "\n";
        while(curr){
            curr->Print(of);
            curr = curr->getParentScope();
        }

    }

};

#endif