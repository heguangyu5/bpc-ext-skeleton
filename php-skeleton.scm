;; 如何编写一个bpc扩展?
;;
;;-------------------
;;
;; 首先,bpc扩展就是一个bigloo scheme library,没有什么特别之处.
;;
;; 除了bigloo scheme内置的功能特性及函数以外,php-runtime export出来的函数都可以用.
;; 这是因为在bigloo编译扩展时添加了 -library php-runtime 参数.
;;
;; 扩展基本上都会给bpc添加函数,类,resource等,所以 load php-macros.scm 是必须的.
;;
;;-------------------
;;
;; 如果一个扩展包含了多个.scm文件,那么需要在一个主文件里import其它所有的module.
;; 然后在这个主文件中定义一个 init-扩展名-lib 的函数并export出去,这个函数什么都不做,仅返回#t.
;;
;; 这么做的原因是为了保证在编译php源码成二进制时,如果链接了该扩展,那么该扩展可以正确初始化.
;;
;;*********详细说明*********
;;
;; 每个扩展编译成.so文件时,通过bigloo参数-dload-sym添加了一个函数bigloo_dlopen_init.
;; bpc在启动过程中,会将bpc.conf中配置的default-lib都通过dynamic-load加载.
;; dynamic-load加载.so时会执行bigloo_dlopen_init.
;; 这个函数保证了.so中包含的各个module都能正确初始化.
;;
;; bpc编译php源码生成scheme时,如果仅包含了(library xxx),最终的二进制文件虽然链接了xxx.so,
;; 但.so中包含的各个module都未初始化.
;; 为了能够让module初始化,我们还需要生成一个xxx.sch文件,然后生成(library xxx)(include "xxx.sch")这样的scheme代码.
;; .sch文件的生成makefile自动处理了,.sch文件中需要包含一个函数调用,这个调用就是 init-扩展名-lib.
;; 由于 init-扩展名-lib 所在的主文件import了其它module,所以其它module也能正确初始化了.
;;
;; 总结下来说,就是: 直接链接.so的情况下,要想让module初始化,就得调用module中的一个函数.
;;
;;-------------------
;;
;; bpc扩展都需要注册到php-runtime里. @see php-runtime.scm::register-extension
;;
;;-------------------
;;
;; 关于数据类型的对照
;;
;;  php         bigloo scheme
;;  NULL        '()
;;  true        #t
;;  false       #f
;;  int         elong
;;  float       flonum
;;  string      string
;;  array       php-hash    (@see php-hash.scm)
;;  object      struct      (@see php-object.scm)
;;  resource    struct      (@see php-macros.scm::defresource)
;;
;; bpc在处理php源码时,会正确处理数据类型,比如
;;  <?php echo "hello ", 2021, " ", 2021.0309; ?>
;; "hello"会识别为string, 2021会识别为#e2021(elong), 2021.0309会识别为flonum.
;;
;; 但在编写扩展函数时,不能假定参数是没问题的,因为参数有可能是变量,其值在编译时无法确定.
;; 另一个原因是扩展函数有可能不只在php源码里调用,我们自己编写scheme代码时也可能会用,所以
;; 会有本来参数应该是个elong的,但我们传了个fixnum过去.
;;
;; php-types.scm提供了以下函数来做数据类型转换:
;;  mkelong
;;  mkflonum
;;  mkfixnum
;;  mkstr
;;  mkbool
;;  mknum
;;
;; 如果需要在转换失败的情况下报warning/exception,php-macros.scm提供了以下宏:
;;  mkstrw
;;  mkelongw
;;  mkflonumw
;;  mkhashw
;;  mkresourcew
;;  mkboolw
;;  mkobjw
;;  mkstre
;;  mkobje
;;
;; 加减乘除运算等 @see php-operators.scm
;;
;; -------------------
;;
;; 和C语言互动
;;
;;  scheme -> C             C -> scheme
;;  $belong->elong          ELONG_TO_BELONG
;;  $real->double           DOUBLE_TO_REAL
;;  $bstring->string        string_to_bstring/string_to_bstring_len/
;;                          make_string/make_string_sans_fill/bgl_string_shrink
;;  $bchar->char            BCHAR
;;
;;  boolean类型要通过 ($bint->int (if #t 1 0)) 这样转换成C
;;  任意scheme类型在C中都是obj_t
;;  php-hash.scm 也可在C中调用,see bpc.h
;;  C中用到scheme的boolean类型是 BTRUE BFALSE
;;  C中用到scheme的'()是 BNIL,对应php的NULL
;;  C中判断obj_t的类型 NULLP BOOLEANP ELONGP REALP STRINGP
;;  C中转换obj_t BELONG_TO_LONG CINT REAL_TO_DOUBLE BSTRING_TO_STRING STRING_LENGTH
;;
;; 特别提示:
;;  php-runtime支持glib,所以C中 #include <bpc.h> 后就可以使用glib的函数了
;;
;; -------------------
;;
;; 如何定义常量?
;;
;; php-macros.scm::defconstant
;;
;; -------------------
;;
;; 如何添加扩展函数?
;;
;; php-macros.scm提供了三个macro:
;;
;; 1. defbuiltin    最常用的就是这个,定义一个内置函数,参数数量有限
;; 2. defbuiltin-v  如果参数数量不定,就用这个,可变参数在函数体里都封装到一个list里了
;; 3. defalias      函数别名,比如fputs就是fwrite的别名,rand是mt_rand的别名等.
;;                  但defalias一定要在defbuiltin后调用,否则会出错.
;;
;; 需要特别提一下的是:
;;
;;  如果php函数和scheme函数名冲突了,此时可以 defbuiltin 一个 "php-" 前缀的函数, 然后 defalias 回正确的函数名.
;;  @see php-errors.scm::php-exit
;;  @see php-math.scm::php-sqrt
;;
;; 另外,添加的扩展函数也都要export出来,这是因为在从php源码生成scheme代码时,扩展函数会直接调用,
;; 如果不export出来,那么编译生成的scheme代码时,就报 Unbound variable 了.
;;
;; -------------------
;;
;; 如何定义新的resource?
;;
;; 不能直接定义struct,要通过php-macros.scm::defresource来定义新的resource.
;;
;; defresource后,创建resource要调用
;;  (make-resource RESOURCE_NAME ARGS)
;;  或者
;;  (make-closable-resource RESOURCE_NAME CLOSE-CALLBACK ARGS)
;; 而不能调用 make-RESOURCE_NAME
;;
;; 这么做是为了实现 php-resource? 及 resource 计数.
;;
;; make-resource 与 make-closable-resource 的区别在于前者由gc释放,后者在程序运行结束或请求结束时调用CLOSE-CALLBACK然后再交由gc释放
;; make-resource适合纯内存型的resource, make-closable-resource适合非纯内存型的resouce,比如fd相关的resouce.
;;
;; 对于closable resource在close时要将description设为#f,description为#f标记着这个resouce已关闭.
;;
;; -------------------
;;
;; 如何定义新的class/interface?
;;
;; @see php-object.scm
;; @see builtin-classes.scm
;; @see date/php-date.scm
;;
;; -------------------

(module php-skeleton
    (load (php-macros "/usr/local/lib/php-macros.scm"))
    (extern
        (include "c.h"))
    (export
        (init-php-skeleton-lib)
        (skel_sayhi)
        (skel_sayhi_with_name name)
        (skel_sayhi_with_name_default_value name)
        (skel_sayhi_with_name_ref name)
        (skel_sayhi_with_name_ref_default_value name)
        (skel_sayhi_with_name_optional name)
        (skel_c_strtoupper str)
        (skel_c_strtoupper_at str index)
        (skel_resource_new name)
        (skel_resource_say handle . words)))

(define (init-php-skeleton-lib)
    #t)

(register-extension "skeleton"      ; extension title, shown in e.g. phpinfo()
                    PHP_VERSION     ; version
                    "php-skeleton") ; library name. make sure this matches LIBNAME in Makefile

; constants

(defconstant SKEL_CONST_INT     #e1)
(defconstant SKEL_CONST_FLOAT   3.1415926)
(defconstant SKEL_CONST_STRING  "skel-constant")

; functions

(defbuiltin (skel_sayhi)
    (echo "Hello\n"))

(defbuiltin (skel_sayhi_with_name name)
    (echo (mkstr-v "Hello, " name "\n")))

(defbuiltin (skel_sayhi_with_name_default_value (name "World"))
    (skel_sayhi_with_name name))

(defbuiltin (skel_sayhi_with_name_ref (ref . name))
    (container-value-set! name "Bob")
    (skel_sayhi_with_name (container-value name)))

(defbuiltin (skel_sayhi_with_name_ref_default_value ((ref . name) "Bob"))
    (if (container? name)
        (begin
            (skel_sayhi_with_name (container-value name))
            (container-value-set! name "John")
            (echo "new name Jhon\n")
            (skel_sayhi_with_name (container-value name)))
        (skel_sayhi_with_name name)))

(defbuiltin (skel_sayhi_with_name_optional (name unpassed))
    (if (eq? name 'unpassed)
        (skel_sayhi)
        (skel_sayhi_with_name name)))

; 为什么要string-copy?
; 因为c函数里直接修改了str,如果str本身就是个字符串的话,mkstr返回的就是str本身,经过c函数后,最初的str就被改变了
; 我们想要的是一份copy,而不是直接修改参数str
; 如果c函数里没有直接修改str,可以不用string-copy
(defbuiltin (skel_c_strtoupper str)
    (pragma::string "bpc_skel_strtoupper($1)" ($bstring->string (string-copy str))))

(defbuiltin (skel_c_strtoupper_at str index)
    (set! index (mkelongw 'skel_c_strtoupper_at 1 index))
    (when index
        (let ((str (mkstr str)))
            (if (or (<elong index #e0)
                    (>=elong index (fixnum->elong (string-length str))))
                (php-warning "index out of range")
                (pragma::string "bpc_skel_strtoupper_at($1, (int)$2)"
                                ($bstring->string (string-copy str))
                                ($belong->elong index))))))

; resource

(defresource skel
             "skel resource"
             name)

(define (close-callback-skel handle)
    (echo (string-append "Goodbye " (skel-name handle) "\n")))

(defbuiltin (skel_resource_new name)
    (make-closable-resource skel close-callback-skel name))

(defbuiltin (skel_resource_close handle)
    (hashtable-remove! *closable-resources* handle)
    (close-callback-skel handle)
    (skel-description-set! handle #f)
    #t)

(defbuiltin-v (skel_resource_say handle words)
    (set! handle (mkresourcew 'skel_resource_say 1 handle))
    (when handle
        (resource-valid-guard
            'skel_resource_say
            (skel? handle)
            "skel"
            (begin
                (echo (mkstr-v "Skel " (skel-name handle) " say: "))
                (for-each (lambda (w)
                                (echo (mkstr-v w " ")))
                          words)
                (echo "\n")))))
