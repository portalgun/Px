#include <unistd.h>
#include <limits.h>

//linux
char hostname[HOST_NAME_MAX];
char username[LOGIN_NAME_MAX];
gethostname(hostname, HOST_NAME_MAX);
getlogin_r(username, LOGIN_NAME_MAX);

// WINDOWS
#define INFO_BUFFER_SIZE 32767
TCHAR  infoBuf[INFO_BUFFER_SIZE];
DWORD  bufCharCount = INFO_BUFFER_SIZE;

// Get and display the name of the computer.
if( !GetComputerName( infoBuf, &bufCharCount ) )
  printError( TEXT("GetComputerName") ); 
_tprintf( TEXT("\nComputer name:      %s"), infoBuf ); 

// Get and display the user name.
if( !GetUserName( infoBuf, &bufCharCount ) )
  printError( TEXT("GetUserName") ); 
_tprintf( TEXT("\nUser name:          %s"), infoBuf );
