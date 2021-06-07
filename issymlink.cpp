#if defined(__WIN64__)
#include "mex.h"
#include <sys/stat.h>
#elif defined(__APPLE__)
#include "mex.h"
#include <sys/stat.h>
#elif defined(__linux__)
#include "mex.h"
#include <sys/stat.h>
#endif
void mexFunction(int nlhs, mxArray *plhs[], 
                 int nrhs, const mxArray *prhs[])

{
  char *FileName;
  struct stat S;
    // Check number and type of arguments:
    if (nrhs != 1) {
      mexErrMsgTxt("*** FileIsLink[mex]: 1 input required.");
    }
    if (nlhs > 1) {
      mexErrMsgTxt("*** FileIsLink[mex]: 1 output allowed.");
    }
    // Type of input arguments:
    if (!mxIsChar(prhs[0])) {
      mexErrMsgTxt("*** FileIsLink[mex]: 1st input must be the file name.");
    }
    // Obtain FileName:
    if ((FileName = mxArrayToString(prhs[0])) == NULL) {
      mexErrMsgTxt("*** FileIsLink[mex]: "
                   "Cannot convert FileName to C-string.");
    }
    // Get the status and create output:
    if (lstat(FileName, &S) == 0) {
      plhs[0] = mxCreateLogicalScalar((mxLogical) S_ISLNK(S.st_mode));
    } else {  // File not found:
      plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
    }
    mxFree(FileName);  
    return;
  }
