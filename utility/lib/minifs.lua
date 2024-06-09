-- A portable filesystem API using LuaJIT's FFI
-- Taken from https://gist.github.com/Wizzard033/2d81f4a88a202e62abfe1795facb482f
-- (Slightly) modified by Kaedenn A. D. N., May 2024

local ffi = require("ffi")
local table = require("table")
require("string")

-- Cache needed functions and locals
local C, errno, string = ffi.C, ffi.errno, ffi.string
local band = bit.band
local concat, insert = table.concat, table.insert

-- "Standard" C99 functions
ffi.cdef[[
char *strerror(int errnum);
]]

local exists, isdir, listdir, mkdir, mtime, PATH_SEPARATOR
if ffi.os == "Windows" then
    ffi.cdef[[
    struct _finddata_t {
        unsigned attrib;
        __time32_t time_create;
        __time32_t time_access;
        __time32_t time_write;
        unsigned long size;
        char name[260];
    };
    struct __stat64 {
        unsigned int st_dev;
        unsigned short st_ino;
        unsigned short st_mode;
        short st_nlink;
        short st_uid;
        short st_gid;
        unsigned int st_rdev;
        int64_t st_size;
        long long st_atime;
        long long st_mtime;
        long long st_ctime;
    };
    int _access(const char *path, int mode);
    intptr_t _findfirst(const char *filespec, struct _finddata_t *fileinfo);
    int _findnext(intptr_t handle, struct _finddata_t *fileinfo);
    int _findclose(intptr_t handle);
    bool CreateDirectoryA(const char *path, void *lpSecurityAttributes);
    int _stat64(const char *path, struct __stat64 *buffer);
    ]]
    local _finddata_t = ffi.typeof("struct _finddata_t")
    local __stat64 = ffi.typeof("struct __stat64")
    function exists(path)
        assert(type(path) == "string", "path isn't a string")
        return C._access(path, 0) == 0 -- Check existence
    end
    function isdir(path)
        local buffer = __stat64()
        if C._stat64(path, buffer) == -1 then
            error("error getting whether '" .. path .. "' is a directory (" .. string(C.strerror(errno())) .. ")")
        end
        return band(buffer.st_mode, 0xF000) == 0x4000
    end
    function listdir(path)
        local data = _finddata_t()
        local handle
        local function nextDir()
            if handle == nil then
                local result = C._findfirst(path .. "/*", data)
                if result == -1 then
                    error("error iterating over directory '" .. path .. "' (" .. string(C.strerror(errno())) .. ")")
                else
                    handle = result
                    result = string(data.name)
                    if result == "." or result == ".." then
                        return nextDir()
                    else
                        return result
                    end
                end
            else
                local result = C._findnext(handle, data)
                if result ~= 0 then
                    if errno() == 2 then
                        -- We're done
                        C._findclose(handle)
                        data = nil
                        handle = nil
                        return nil
                    else
                        error("error iterating over directory '" .. path .. "' (" .. string(C.strerror(errno())) .. ")")
                    end
                else
                    result = string(data.name)
                    if result == "." or result == ".." then
                        return nextDir()
                    else
                        return result
                    end
                end
            end
        end
        return nextDir
    end
    function mkdir(path)
        assert(type(path) == "string", "path isn't a string")
        if not C.CreateDirectoryA(path, nil) then
            error("unable to create directory '" .. path .. "' (" .. string(C.strerror(errno())) .. ")")
        end
    end
    function mtime(path)
        local buffer = __stat64()
        if C._stat64(path, buffer) == -1 then
            error("error getting modification time for '" .. path .. "' (" .. string(C.strerror(errno())) .. ")")
        end
        return tonumber(buffer.st_mtime)
    end
    PATH_SEPARATOR = "\\"
elseif ffi.os == "Linux" or ffi.os == "OSX" then
    ffi.cdef[[
    struct dirent {
        unsigned long int d_ino;
        long int d_off;
        unsigned short d_reclen;
        unsigned char  d_type;
        char name[256];
    };
    typedef struct __dirstream DIR;
    int access(const char *path, int amode);
    DIR *opendir(const char *name);
    struct dirent *readdir(DIR *dirp);
    int closedir(DIR *dirp);
    int mkdir(const char *path, int mode);
    typedef size_t time_t;
    ]]
    local stat_func
    if ffi.os == "Linux" then
        ffi.cdef[[
        long syscall(int number, ...);
        ]]
        local stat_syscall_num
        if ffi.arch == "x64" then
            ffi.cdef[[
            struct stat {
                unsigned long st_dev;
                unsigned long st_ino;
                unsigned long st_nlink;
                unsigned int st_mode;
                unsigned int st_uid;
                unsigned int st_gid;
                unsigned int __pad0;
                unsigned long st_rdev;
                long st_size;
                long st_blksize;
                long st_blocks;
                unsigned long st_atime;
                unsigned long st_atime_nsec;
                unsigned long st_mtime;
                unsigned long st_mtime_nsec;
                unsigned long st_ctime;
                unsigned long st_ctime_nsec;
                long  __unused[3];
            };
            ]]
            stat_syscall_num = 4
        elseif ffi.arch == "x86" then
            ffi.cdef[[
            struct stat {
                unsigned long long st_dev;
                unsigned char __pad0[4];
                unsigned long __st_ino;
                unsigned int st_mode;
                unsigned int st_nlink;
                unsigned long st_uid;
                unsigned long st_gid;
                unsigned long long st_rdev;
                unsigned char __pad3[4];
                long long st_size;
                unsigned long st_blksize;
                unsigned long long st_blocks;
                unsigned long st_atime;
                unsigned long st_atime_nsec;
                unsigned long st_mtime;
                unsigned int st_mtime_nsec;
                unsigned long st_ctime;
                unsigned long st_ctime_nsec;
                unsigned long long st_ino;
            };
            ]]
            stat_syscall_num = ffi.abi("64bit") and 106 or 195
        elseif ffi.arch == "arm" then
            if ffi.abi("64bit") then
                ffi.cdef[[
                struct stat {
                    unsigned long st_dev;
                    unsigned long st_ino;
                    unsigned int st_mode;
                    unsigned int st_nlink;
                    unsigned int st_uid;
                    unsigned int st_gid;
                    unsigned long st_rdev;
                    unsigned long __pad1;
                    long st_size;
                    int st_blksize;
                    int __pad2;
                    long st_blocks;
                    long st_atime;
                    unsigned long st_atime_nsec;
                    long st_mtime;
                    unsigned long st_mtime_nsec;
                    long st_ctime;
                    unsigned long st_ctime_nsec;
                    unsigned int __unused4;
                    unsigned int __unused5;
                };
                ]]
                stat_syscall_num = 106
            else
                ffi.cdef[[
                struct stat {
                    unsigned long long st_dev;
                    unsigned char __pad0[4];
                    unsigned long __st_ino;
                    unsigned int st_mode;
                    unsigned int st_nlink;
                    unsigned long st_uid;
                    unsigned long st_gid;
                    unsigned long long st_rdev;
                    unsigned char __pad3[4];
                    long long st_size;
                    unsigned long st_blksize;
                    unsigned long long st_blocks;
                    unsigned long st_atime;
                    unsigned long st_atime_nsec;
                    unsigned long st_mtime;
                    unsigned int st_mtime_nsec;
                    unsigned long st_ctime;
                    unsigned long st_ctime_nsec;
                    unsigned long long st_ino;
                };
                ]]
                stat_syscall_num = 195
            end
        elseif ffi.arch == "ppc" or ffi.arch == "ppcspe" then
            ffi.cdef[[
            struct stat {
                unsigned long long st_dev;
                unsigned long long st_ino;
                unsigned int st_mode;
                unsigned int st_nlink;
                unsigned int st_uid;
                unsigned int st_gid;
                unsigned long long st_rdev;
                unsigned long long __pad1;
                long long  st_size;
                int st_blksize;
                int __pad2;
                long long st_blocks;
                int st_atime;
                unsigned int st_atime_nsec;
                int st_mtime;
                unsigned int st_mtime_nsec;
                int st_ctime;
                unsigned int st_ctime_nsec;
                unsigned int __unused4;
                unsigned int __unused5;
            };
            ]]
            stat_syscall_num = ffi.abi("64bit") and 106 or 195
        elseif ffi.arch == "mips" or ffi.arch == "mipsel" then
            ffi.cdef[[
            struct stat {
                unsigned long st_dev;
                unsigned long __st_pad0[3];
                unsigned long long st_ino;
                mode_t st_mode;
                nlink_t st_nlink;
                uid_t st_uid;
                gid_t st_gid;
                unsigned long st_rdev;
                unsigned long __st_pad1[3];
                long long st_size;
                time_t st_atime;
                unsigned long st_atime_nsec;
                time_t st_mtime;
                unsigned long st_mtime_nsec;
                time_t st_ctime;
                unsigned long st_ctime_nsec;
                unsigned long st_blksize;
                unsigned long __st_pad2;
                long long st_blocks;
                long __st_padding4[14];
            };
            ]]
            stat_syscall_num = ffi.abi("64bit") and 4106 or 4213
        end
        if stat_syscall_num then
            stat_func = function(path, buffer)
                return C.syscall(stat_syscall_num, path, buffer)
            end
        else
            stat_func = function(path, buffer)
                error("unsupported architecture (" .. ffi.arch .. ")")
            end
        end
    elseif ffi.os == "OSX" then
        ffi.cdef[[
        struct timespec {
            time_t tv_sec;
            long tv_nsec;
        };
        struct stat {
            uint32_t st_dev;
            uint16_t st_mode;
            uint16_t st_nlink;
            uint64_t st_ino;
            uint32_t st_uid;
            uint32_t st_gid;
            uint32_t st_rdev;
            struct timespec st_atimespec;
            struct timespec st_mtimespec;
            struct timespec st_ctimespec;
            struct timespec st_birthtimespec;
            int64_t st_size;
            int64_t st_blocks;
            int32_t st_blksize;
            uint32_t st_flags;
            uint32_t st_gen;
            int32_t st_lspare;
            int64_t st_qspare[2];
        };
        int stat64(const char *path, struct stat *buf);
        ]]
        stat_func = C.stat64
    end
    local stat = ffi.typeof("struct stat")
    function exists(path)
        assert(type(path) == "string", "path isn't a string")
        return C.access(path, 0) == 0 -- Check existence
    end
    function isdir(path)
        local buffer = stat()
        if stat_func(path, buffer) == -1 then
            error("error getting whether '" .. path .. "' is a directory (" .. string(C.strerror(errno())) .. ")")
        end
        return band(buffer.st_mode, 0xF000) == 0x4000
    end
    function listdir(path)
        local dir = C.opendir(path)
        if dir == nil then
            -- Kaedenn A. D. N.: replace `dir` with `path`
            error("error opening directory '" .. path .. "' (" .. string(C.strerror(errno())) .. ")")
        end
        local function nextDir()
            local entry = C.readdir(dir)
            if entry ~= nil then
                local result = string(entry.name)
                if result == "." or result == ".." then
                    return nextDir()
                else
                    return result
                end
            else
                C.closedir(dir)
                dir = nil
                return nil
            end
        end
        return nextDir
    end
    function mkdir(path, mode)
        assert(type(path) == "string", "path isn't a string")
        if C.mkdir(path, tonumber(mode or "755", 8)) ~= 0 then
            error("Unable to create directory " .. path .. ": " .. string(C.strerror(errno())))
        end
    end
    if ffi.os == "Linux" then
        function mtime(path)
            local buffer = stat()
            if stat_func(path, buffer) == -1 then
                error("error getting modification time for '" .. path .. "' (" .. string(C.strerror(errno())) .. ")")
            end
            return tonumber(buffer.st_mtime)
        end
    elseif ffi.os == "OSX" then
        function mtime(path)
            local buffer = stat()
            if stat_func(path, buffer) == -1 then
                error("error getting modification time for '" .. path .. "' (" .. string(C.strerror(errno())) .. ")")
            end
            return tonumber(buffer.st_mtimespec.tv_sec)
        end
    end
    PATH_SEPARATOR = "/"
else
    error("unsupported operating system (" .. ffi.os .. ")")
end

local function join(...)
    local parts = {}
    for i = 1, select("#", ...) do
        insert(parts, select(i, ...))
    end
    return concat(parts, PATH_SEPARATOR)
end

local function splitpath(path)
    assert(type(path) == "string", "path isn't a string")
    local parts = {}
    local lastIndex = 0
    for i = 1, path:len() do
        local c = path:sub(i, i)
        if c == "/" or c == "\\" then
            insert(parts, path:sub(lastIndex, i - 1))
            lastIndex = i + 1
        end
    end
    insert(parts, path:sub(lastIndex))
    return parts
end

local function mkdirs(path)
    local parts = splitpath(path)
    local currentPath = parts[1]
    for i = 2, #parts do
        if not exists(currentPath) then
            mkdir(currentPath)
        end
        -- Note: This isn't suboptimal, since we really do need the intermediate results
        currentPath = currentPath .. PATH_SEPARATOR .. parts[i]
    end
    if not exists(path) then
        mkdir(path)
    end
end

return {
    exists = exists,
    isdir = isdir,
    join = join,
    mkdir = mkdir,
    mkdirs = mkdirs,
    splitpath = splitpath,
    listdir = listdir,
    mtime = mtime,
    PATH_SEPARATOR = PATH_SEPARATOR
}
