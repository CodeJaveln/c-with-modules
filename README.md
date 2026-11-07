# C With Modules
The language adds two additions to C syntax:
`#import string-literal`
and
`#export open`
`#export close`
and file extension is `.cm`.

Currently each `.cm` file is it's own module and transpiled to a `.c` source file and `.h` header file.

## TODO
Formalize a style (where to put exports, naming and so on)
Implementation lol

## Import
This declares a dependency of another module (`.cm`), and also in the outputed `.c` files it includes the corresponding module header. If the import is also exported then it is added in the header.

More complicated though

## Export
Exports a statement to the header.
Basically cut out of the source file and put into the header.

Header:
```c
#ifndef FILE_NAME_H
#define FILE_NAME_H

// Exported stuff:

#endif // FILE_NAME_H
```

Source:
```c
#include "file_name.h"

// Basically the cm without the imports (changed to includes)
// and exports removed
```
