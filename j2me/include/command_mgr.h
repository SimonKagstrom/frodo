#ifndef __COMMAND_MGR_H__
#define __COMMAND_MGR_H__

#include <cibyl.h>

/* CommandMgr class (this is not in J2ME) */
typedef int NOPH_CommandMgr_t;

#define __NR_NOPH_CommandMgr_getInstance 0 /* command_mgr */
static inline _syscall0(NOPH_CommandMgr_t,NOPH_CommandMgr_getInstance) 
#define __NR_NOPH_CommandMgr_setList_internal 1 /* command_mgr */
static inline _syscall4(void,NOPH_CommandMgr_setList_internal, NOPH_CommandMgr_t, cm, NOPH_List_t, l, void*, callback, void*, arg) 
static inline void NOPH_CommandMgr_setList(NOPH_CommandMgr_t cm, NOPH_List_t l, void (*callback)(void*), void* arg)
{
NOPH_CommandMgr_setList_internal(cm, l, (void*)callback, arg);
}

#define __NR_NOPH_CommandMgr_addCommand_internal 2 /* command_mgr */
static inline _syscall5(void,NOPH_CommandMgr_addCommand_internal, NOPH_CommandMgr_t, cm, int, type, const char*, name, void*, callback, void*, arg) 

static inline void NOPH_CommandMgr_addCommand(NOPH_CommandMgr_t cm, int type, const char* name,
void (*callback)(void*), void* arg)
{
NOPH_CommandMgr_addCommand_internal(cm, type, name, (void*)callback, arg);
}

#endif /* !__COMMAND_MGR_H__ */
