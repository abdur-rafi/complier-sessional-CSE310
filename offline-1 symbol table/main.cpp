#include <iostream>
#include <string>
#include <fstream>

using namespace std;

class SymbolInfo{

    string name, type;
    SymbolInfo* next;


public:

    SymbolInfo(string n,string t, SymbolInfo* next){
        name = n;
        type = t;
        this->next = next;
    }

    SymbolInfo(string n,string t): SymbolInfo(n, t, nullptr){}

    string getName(){
        return name;
    }

    SymbolInfo* getNext(){
        return next;
    }

    void setNext(SymbolInfo* next){
        this->next = next;
    }

    void Print(){
        cout << " < " << name << " : " << type << " > ";
    }
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
//            cout << "r : " << r << "\n";
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
                cout << "Found in ScopeTable# " << id <<" at position " << bucketIndex << ", " << c << "\n";

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
                symbol->Print();
                cout << "already exists in current ScopeTable\n";
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
        cout << "Inserted in ScopeTable# " << id <<" at position " << bucketIndex << ", " << c << "\n";
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
                cout << "Deleted Entry " << bucketIndex << ", " << c << " from current ScopeTable\n";
                return true;
            }
            ++c;
            prev = curr;
            curr = curr->getNext();
        }
        cout << "Symbol not found in current ScopeTable\n";

        return false;


    }

    ScopeTable* getParentScope(){
        return parentScope;
    }

    void Print(){
        cout << "ScopeTable # " << id << "\n";
        for(int i = 0; i < total_buckets; ++i){
            cout << i << " --> " ;
            SymbolInfo* curr = buckets[i];
            while(curr){
                curr->Print();
                curr = curr->getNext();
            }
            cout << "\n";
        }
    }

    string getId(){
        return id;
    }
};

class SymbolTable{
    ScopeTable *curr;
    int topLevelCount = 0;
    int bucketSize;
    int defaultBucketSize = 10;

public:
    SymbolTable() : SymbolTable(defaultBucketSize){}

    SymbolTable(int bSize){
        curr = nullptr;
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

    void ExitScope(){
        if(curr){
            ScopeTable *parent = curr->getParentScope();
            cout << "ScopeTable with id " << curr->getId() << " removed\n";
            delete curr;
            curr = parent;
        }
        else{
            cout << "No current scope\n";
        }
    }

    bool Insert(SymbolInfo *symbol){
        if(!curr) EnterScope();
        return curr->Insert(symbol);

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
        cout << "Not Found\n";
        return nullptr;
    }

    ~SymbolTable(){
        while(curr){
            ScopeTable* t = curr->getParentScope();
            delete curr;
            curr = t;
        }
    }

    void PrintCurrentScopeTable(){
        if(curr){
            curr->Print();
        }
    }

    void PrintAllScopeTable(){
        ScopeTable* curr = this->curr;
        while(curr){
            curr->Print();
            cout << "\n\n";
            curr = curr->getParentScope();
        }
    }

};


void takeInput(string inputFileName){
    ifstream inputFile;
    inputFile.open(inputFileName);
    if(inputFile.is_open()){
        int n;
        inputFile >> n;
        SymbolTable* symTable = new SymbolTable(n);

        while(inputFile.peek() != EOF){
            string command, name, type, nxt,symb;

            inputFile >> command;
            switch(command[0]){
            case 'S':
                cout << "s\n\nNew ScopeTable with id " << symTable->EnterScope() << " created\n\n";
                break;
            case 'I':
                inputFile >> name >> type;
                cout << "I " << name << " " << type << " \n\n";
                symTable->Insert(new SymbolInfo(name, type));
                cout << "\n";
                break;

            case 'P':
                inputFile >> nxt;
//                cout << nxt;
                if(nxt == "A"){
                    cout << "P A\n\n\n";
                    symTable->PrintAllScopeTable();
                    cout << "\n";
                }
                else if(nxt == "C"){
                    cout << "P C\n\n\n";
                    symTable->PrintCurrentScopeTable();
                    cout << "\n";
                }
                break;
            case 'L':
                inputFile >> symb;
                cout << "L " << symb << "\n\n";
                symTable->LookUp(symb);
                cout << "\n";
                break;
            case 'D':
                inputFile >> symb;
                cout << "D " << symb << "\n\n";
                symTable->Remove(symb);
                cout << "\n";
                break;
            case 'E':
                cout << "E\n\n";
                symTable->ExitScope();
                cout << "\n";
            }


        }

        inputFile.close();
    }


}

int main(){
    freopen("output.txt","w",stdout);
    string fileName = "input.txt";
    takeInput(fileName);
//    Test();
    return 0;
}
