/**
   Integration tests that stem from failues in real-life C projects
 */
module it.compile.projects;

import it.compile;

@("nn_get_statistic")
@safe unittest {
    shouldCompile(
        C(
            // the original uses regular uint64_t, let's beat any special cases
            // defining our own
            q{
                typedef unsigned long int __my_uint64_t;
                typedef __my_uint64_t my_uint64_t;
                my_uint64_t nn_get_statistic (int s, int stat);
            }
        ),

        D(
            q{
                int s;
                int stat;
                my_uint64_t ret = nn_get_statistic(s, stat);
            }
        )
    );
}

@("__io_read_fn")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef long long __ssize_t;
                typedef __ssize_t __io_read_fn (void *__cookie, char *__buf, size_t __nbytes);
            }
        ),

        D(
            q{
                void* cookie;
                char[1024] buf;
                __ssize_t ret = __io_read_fn.init(cookie, buf.ptr, buf.length);
            }
        ),
    );
}

@("timer_t")
@safe unittest {
    shouldCompile(
        C(
            // the original uses regular uint64_t, let's beat any special cases
            // defining our own
            q{
                #define __TIMER_T_TYPE void *
                typedef __TIMER_T_TYPE __timer_t;
            }
        ),

        D(
            q{
                __timer_t timer = null;
            }
        ),
    );
}


@("curl_multi_wait")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef enum { CURLM_OK } CURLMcode;
                typedef int curl_socket_t;

                struct curl_waitfd {
                    curl_socket_t fd;
                    short events;
                    short revents; /* not supported yet */
                };

                typedef struct { int dummy; } CURLM;
                CURLMcode curl_multi_wait(CURLM *multi_handle,
                                          struct curl_waitfd extra_fds[],
                                          unsigned int extra_nfds,
                                          int timeout_ms,
                                          int *ret);
            }
        ),

        D(
            q{
                CURLM handle;
                struct_curl_waitfd[] extra_fds;
                int ret;
                CURLMcode code = curl_multi_wait(&handle, extra_fds.ptr, 42u, 33, &ret);
            }
         ),
    );
}

@("__sigset_t")
@safe unittest {
    shouldCompile(
        // the original uses regular uint64_t, let's beat any special cases
        // defining our own
        C(
             q{
                 #define _SIGSET_NWORDS (1024 / (8 * sizeof (unsigned long int)))
                 typedef struct
                 {
                     unsigned long int __val[_SIGSET_NWORDS];
                 } __sigset_t;
             }
        ),
        D(
            q{
                auto s = __sigset_t();
                ++s.__val[7];
            }
        ),
    );
}


@("_IO_flockfile")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct _IO_FILE { int dummy; };
                extern void _IO_flockfile (struct _IO_FILE *);
                #define _IO_flockfile(_fp)
            }
        ),
        D(
            q{
                struct__IO_FILE file;
                _IO_flockfile(&file);
            }
        ),
    );
}

@Tags("travis")
@("struct with union")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    union {
                        void *ptr;
                        int i;
                    } data;
                };
                typedef struct Struct Struct;
            }
        ),

        D(
            q{
                struct_Struct s;
                s.data.ptr = null;
                s.data.i = 42;
            }
        ),
    );
}

@("const char* const")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    const char * const *protocols;
                };
                typedef struct Struct Struct;
            }
        ),

        D(
            q{
                Struct s;
                static assert(is(typeof(s.protocols) == const(char*)*),
                              "Expected const(char*)*, not " ~
                              typeof(s.protocols).stringof);
            }
        ),
     );
}

@("forward declaration")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct;
                void fun(struct Struct* s);
                struct Struct* make_struct(void);
            }
        ),

        D(
            q{
                struct_Struct* s = make_struct();
                fun(s);
            }
        ),
    );
}


@("restrict")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct FILE { int dummy; }
                extern FILE *fopen(const char *restrict filename,
                                   const char *restrict modes);
            }
        ),

        D(
            q{
                import std.string;
                fopen("foo.txt".toStringz, "w".toStringz);
            }
        ),
    );
}


@("return type typedefd enum")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct { int dummy; } CURL;

                typedef enum {
                    CURLIOE_OK,            /* I/O operation successful */
                } curlioerr;

                typedef curlioerr (*curl_ioctl_callback)(CURL *handle,
                                                         int cmd,
                                                         void *clientp);
            }
        ),
        D(
            q{
                CURL handle;
                auto func = curl_ioctl_callback.init;
                curlioerr err = func(&handle, 42, null);
            }
        ),
    );
}


@("curl_slist")
@safe unittest {
    shouldCompile(
        C(
            q{
                   struct curl_httppost {
                       struct curl_slist *contentheader;
                   };
                   struct curl_slist {
                       char *data;
                       struct curl_slist *next;
                   };
               }
        ),
        D(
            q{
                struct_curl_httppost p;
                p.contentheader.data = null;
                p.contentheader.next = null;
                struct_curl_slist l;
                l.data = null;
                l.next = null;
            }
        ),
    );
}

@("name collision between struct and var")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct timezone {
                    int tz_minuteswest;
                    int tz_dsttime;
                };
                extern long int timezone;
            }
        ),

        D(
            q{
                timezone = 42;
                auto s = struct_timezone(33, 77);
            }
        ),
    );
}

@("use int for enum parameter")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef enum {
                    foo,
                    bar,
                } Enum;
                void func(Enum e);
            }
        ),
        D(
            q{
                func(Enum.bar);
            }
        ),
    );
}

@("pthread struct")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   typedef struct {
                       void (*routine)(void*);
                   } Struct;
               }
        );
        writeFile("app.d",
                  q{
                      import hdr;
                      extern(C) void foo(void*) {}

                      void main() {
                          Struct s;
                          s.routine = &foo;
                      }
                  }
        );

        shouldCompile("app.d", "hdr.d");
    }
}


@("multiple headers with the same typedef")
@safe unittest {
    with(const IncludeSandbox()) {
        writeFile("hdr1.h",
                  q{
                      typedef long time_t;
                      typedef long time_t;
            }
        ),

        writeFile("hdr2.h",
                  q{
                      typedef long time_t;
                      typedef long time_t;
            }
        ),

        writeFile("app.d_",
                  q{
                      #include "%s"
                      #include "%s"
                      void main() {
                          time_t var = 42;
                      }
                  }.format(inSandboxPath("hdr1.h"), inSandboxPath("hdr2.h")));

        preprocess("app.d_", "app.d");
        shouldCompile("app.d");
    }
}

@("jmp_buf")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef long int __jmp_buf[8];
            }
        ),

        D(
            q{
                __jmp_buf buf;
                static assert(buf.length == 8);
            }
        ),
    );
}

@("__pthread_unwind_buf_t")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef long int __jmp_buf[8];
                typedef struct {
                    struct {
                        __jmp_buf __cancel_jmp_buf;
                        int __mask_was_saved;
                    } __cancel_jmp_buf[1];
                    void *__pad[4];
                } __pthread_unwind_buf_t __attribute__ ((__aligned__));
            }
        ),

        D(
            q{
                __pthread_unwind_buf_t buf;
            }
        ),
    );
}
