/// Sequential entity ids for synthetic drawings. Starts at 1.
class DocIds {
  DocIds([this._next = 1]);

  int _next;

  int next() => _next++;
}

/// A fresh [DocIds] counter.
DocIds docIds() => DocIds();
