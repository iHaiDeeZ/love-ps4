#include "compat.h"

#if LUA_VERSION_NUM==501
/*
** Adapted from Lua 5.2
*/
#if defined(__GNUC__) || defined(__clang__)
/* LuaJIT 2.1 has its own; don't clash with it when it's linked statically (PS4). */
__attribute__((weak))
#endif
void luaL_setfuncs (lua_State *L, const luaL_Reg *l, int nup) {
  luaL_checkstack(L, nup+1, "too many upvalues");
  for (; l->name != NULL; l++) {  /* fill the table with given functions */
    int i;
    lua_pushstring(L, l->name);
    for (i = 0; i < nup; i++)  /* copy upvalues to the top */
      lua_pushvalue(L, -(nup+1));
    lua_pushcclosure(L, l->func, nup);  /* closure with those upvalues */
    lua_settable(L, -(nup + 3));
  }
  lua_pop(L, nup);  /* remove upvalues */
}
#endif
