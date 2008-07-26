#ifndef __FORM_COMMAND_MGR_H__
#define __FORM_COMMAND_MGR_H__

#include <cibyl.h>
#include "javax/microedition/lcdui.h"

/* FormCommandMgr class (this is not in J2ME) */
typedef int NOPH_FormCommandMgr_t;

#define __NR_NOPH_FormCommandMgr_new 3 /* command_mgr */
static inline _syscall1(NOPH_FormCommandMgr_t,NOPH_FormCommandMgr_new, NOPH_Form_t, form) 
#define __NR_NOPH_FormCommandMgr_addCommand 4 /* command_mgr */
static inline _syscall5(void,NOPH_FormCommandMgr_addCommand, NOPH_FormCommandMgr_t, fc, const char*, name, void*, c_addr, char*, c_name, void*, c_context) 
#define __NR_NOPH_FormCommandMgr_setCallBackNotif 5 /* command_mgr */
static inline _syscall3(void,NOPH_FormCommandMgr_setCallBackNotif, int*, callback_addr, void*, callback_name, void*, callback_context) 
#define __NR_NOPH_FormCommandMgr_addCallback 6 /* command_mgr */
static inline _syscall5(void,NOPH_FormCommandMgr_addCallback, NOPH_FormCommandMgr_t, fc, NOPH_Item_t, item, void*, c_addr, char*, c_name, void*, c_context) 

#endif /* !__FORM_COMMAND_MGR_H__ */
