#include "mex.h"
#include <unistd.h>

void mexFunction(int nlhs, mxArray *plhs[], 
                 int nrhs, const mxArray *prhs[])
{
    const char* src 
    const char* dest 
    src = mxArrayToString(prhs[0])
    dest = mxArrayToString(prhs[1])
    plhs[0] = mxCreateLogicalScalar((mxLogical) symlink(src, dest))
}
