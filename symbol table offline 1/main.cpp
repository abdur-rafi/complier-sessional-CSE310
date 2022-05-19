#include <iostream>
#include <string>


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
};

class ScopeTable{

    SymbolInfo* *buckets;
    int total_buckets;
    ScopeTable *parentScope;
    int childCount;
    string id;

    long long sdbmhash(string key){
        long long r = 0;
        int n = key.size();
        for(int i = 0; i < n; ++i){
            r = (r << 6) + (r << 16) + key[i] - r;
        }
        return r;
    }
    int calcBucketIndex(string key){
        return sdbmhash(key) % total_buckets;
    }

    SymbolInfo* Search(string key, bool returnPrevIfExist){

        int bucketIndex = calcBucketIndex(key);
        SymbolInfo* curr = buckets[bucketIndex];
        SymbolInfo* prev = curr;

        while(curr){
            if(curr->getName() == key){
                return returnPrevIfExist ? prev : curr;
            }
            prev = curr;
            curr = curr->getNext();
        }
        return nullptr;
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
            id = this->parentScope->id + to_string(this->parentScope->childCount);
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
        return Search(key, false);
    }

    bool Insert(SymbolInfo *symbol){
        if(LookUp(symbol->getName())){
            return false;
        }

        int bucketIndex = calcBucketIndex(symbol->getName());
        SymbolInfo* currEntry = buckets[bucketIndex];
        buckets[bucketIndex] = symbol;
        symbol->setNext(currEntry);
    }

    bool Delete(string key){
        SymbolInfo* prevItem = Search(key, true);
        if(!prevItem){
            return false;
        }
        SymbolInfo* toDelete;
        if(prevItem->getName() == key){
            toDelete = prevItem;
            int bucketIndex = calcBucketIndex(key);
            buckets[bucketIndex] = nullptr;
        }
        else{
            toDelete = prevItem->getNext();
            prevItem->setNext(prevItem->getNext()->getNext());
        }
        delete toDelete;
    }

    ScopeTable* getParentScope(){
        return parentScope;
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

    void EnterScope(){
        if(!curr){
            topLevelCount++;
            curr = new ScopeTable(bucketSize,topLevelCount);
        }
        else
            curr = new ScopeTable(bucketSize,curr);

    }

    void ExitScope(){
        if(curr){
            ScopeTable *parent = curr->getParentScope();
            delete curr;
            curr = parent;
        }
    }

    bool Insert(SymbolInfo *symbol){
        if(!curr) return false;
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
            if(ret->getName() == key) return ret;
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

};

void Test(){
    SymbolInfo* t = new SymbolInfo("a", "identifier");
    ScopeTable* table = new ScopeTable(5, 1);
    cout << (bool) table->LookUp(t->getName());
    table->Insert(t);
    cout << (bool) table->LookUp(t->getName());
    cout << (bool) table->Insert(t);
    cout << (bool) table->Delete(t->getName());
}


int main(){
    Test();
    return 0;
}
