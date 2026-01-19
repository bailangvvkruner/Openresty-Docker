# FROM alpine:3.20 AS builder
FROM alpine:latest AS builder

# WORKDIR /build

# 安装构建依赖
RUN set -eux \
    && apk add --no-cache --no-scripts --virtual .build-deps \
    build-base \
    curl \
    pcre2-dev \
    zlib-dev \
    linux-headers \
    perl \
    sed \
    grep \
    tar \
    bash \
    jq \
    git \
    autoconf \
    automake \
    libtool \
    cmake \
    tree \
    # 包含strip命令
    binutils \
    && \
    # 尝试安装 upx，如果不可用则继续（某些架构可能不支持）
    apk add --no-cache --no-scripts --virtual .upx-deps \
        upx 2>/dev/null || echo "upx not available, skipping compression" \
    \
    && \
    # 工作路径 替代 WORKDIR /tmp
    cd /tmp && \
    # OPENRESTY_VERSION=$(wget --timeout 10 -q -O - https://openresty.org/en/download.html | grep -oE 'openresty-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    OPENRESTY_VERSION=$(wget --timeout=10 -q -O - https://openresty.org/en/download.html \
    | grep -ioE 'openresty [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
    | head -n1 \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+') \
    && \
    OPENSSL_VERSION=$(wget -q -O - https://www.openssl.org/source/ | grep -oE 'openssl-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    && \
    # ZLIB_VERSION=$(wget -q -O - https://zlib.net/ | grep -oE 'zlib-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    ZLIB_VERSION=$(curl -sL https://github.com/madler/zlib/releases/latest | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -c2-) \
    && \
    ZSTD_VERSION=$(curl -Ls https://github.com/facebook/zstd/releases/latest | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -c2-) \
    && \
    CORERULESET_VERSION=$(curl -s https://api.github.com/repos/coreruleset/coreruleset/releases/latest | grep -oE '"tag_name": "[^"]+' | cut -d'"' -f4 | sed 's/v//') \
    && \
    CORERULESET_VERSION=$(curl -s https://api.github.com/repos/coreruleset/coreruleset/releases/latest | grep -oE '"tag_name": "[^"]+' | cut -d'"' -f4 | sed 's/v//') \
    && \
    NGX_BROTLI_VERSION=$(curl -sL https://github.com/google/ngx_brotli/releases/ | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -c2-) \
    && \
    BROTLI_VERSION=$(curl -sL https://github.com/google/brotli/releases/ | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -c2-) \
    && \
    # PCRE_VERSION=$(curl -sL https://sourceforge.net/projects/pcre/files/pcre/ \
    # | grep -oE 'pcre/[0-9]+\.[0-9]+/' \
    # | grep -oE '[0-9]+\.[0-9]+' \
    # | sort -Vr \
    # | head -n1) \
    PCRE2_VERSION=$(curl -sL https://github.com/PCRE2Project/pcre2/releases/ | grep -ioE 'pcre2-[0-9]+\.[0-9]+' | grep -v RC | cut -d'-' -f2 | sort -Vr | head -n1) \
    && \
    echo "=============版本号=============" && \
    echo "OPENRESTY_VERSION=${OPENRESTY_VERSION}" && \
    echo "OPENSSL_VERSION=${OPENSSL_VERSION}" && \
    echo "ZLIB_VERSION=${ZLIB_VERSION}" && \
    echo "ZSTD_VERSION=${ZSTD_VERSION}" && \
    echo "CORERULESET_VERSION=${CORERULESET_VERSION}" && \
    # echo "PCRE_VERSION=${CORERULESET_VERSION}" && \
    echo "PCRE2_VERSION=${PCRE2_VERSION}" && \
    echo "NGX_BROTLI_VERSION=${NGX_BROTLI_VERSION}" && \
    echo "BROTLI_VERSION=${BROTLI_VERSION}" && \
    \
    curl -fSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz -o openresty.tar.gz && \
    # curl -fSL https://github.com/openresty/openresty/releases/download/v${OPENRESTY_VERSION}/openresty-${OPENRESTY_VERSION}.tar.gz  && \
    tar xzf openresty.tar.gz && \
    \
    curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    \
    # curl -fSL https://fossies.org/linux/misc/zlib-${ZLIB_VERSION}.tar.gz -o zlib.tar.gz && \
    # tar xzf zlib.tar.gz && \
    curl -fSL https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz -o zlib.tar.gz && \
    tar xzf zlib.tar.gz && \
    \
    # curl -fSL https://sourceforge.net/projects/pcre/files/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.gz/download -o pcre.tar.gz && \
    # tar xzf pcre.tar.gz && \
    curl -fSL https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.gz -o pcre2.tar.gz && \
    tar xzf pcre2.tar.gz && \
    \
    curl -fSL https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz -o zstd.tar.gz && \
    tar xzf zstd.tar.gz && \
    # zstd模块 brotli模块
    cd /tmp && \
    git clone --depth 1 --recurse-submodules https://github.com/google/ngx_brotli.git && \
    git clone --depth=1 https://github.com/tokers/zstd-nginx-module.git && \
    cd ngx_brotli/deps/brotli && \
    mkdir out && cd out && \
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=/usr/local/brotli .. && \
    make -j$(nproc) && \
    make install && \
    cd /tmp/zstd-${ZSTD_VERSION} && \
    make -j$(nproc) && \
    make install PREFIX=/usr/local/zstd && \
    cd /tmp && \
    cd openresty-${OPENRESTY_VERSION} && \
    # 申明两个模块路径
    export ZSTD_INC=/usr/local/zstd/include && \
    export ZSTD_LIB=/usr/local/zstd/lib && \
    ./configure \
    # --prefix=/usr/local \
    # --modules-path=/usr/local/nginx/modules \
    # --sbin-path=/usr/local/nginx/sbin/nginx \
    # --conf-path=/usr/local/nginx/conf/nginx.conf \
    # --error-log-path=/usr/local/nginx/logs/error.log \
    # --http-log-path=/usr/local/nginx/logs/access.log \
    # # --with-cc-opt="-static -O3 -DNGX_LUA_ABORT_AT_PANIC -static-libgcc" \
    # # --with-ld-opt="-static -Wl,--export-dynamic" \
    --prefix=/etc/nginx \
    --modules-path=/etc/nginx/modules \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --with-cc-opt="-O3 -DNGX_LUA_ABORT_AT_PANIC" \
    --with-ld-opt="-Wl,--export-dynamic" \
    --with-openssl=../openssl-${OPENSSL_VERSION} \
    --with-zlib=../zlib-${ZLIB_VERSION} \
    # --with-pcre=../pcre-${PCRE_VERSION} \
    --with-pcre=../pcre2-${PCRE2_VERSION} \
    # # 两压缩模块
    --add-module=../ngx_brotli \
    --add-module=../zstd-nginx-module \
    --with-ipv6 \
    --with-pcre-jit \
    --with-stream \
    --user=nobody \
    --group=nobody \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-http_v2_module \
    --without-mail_pop3_module \
    --without-mail_imap_module \
    --without-mail_smtp_module \
    --with-http_stub_status_module  \
    --with-http_realip_module \
    --with-http_gzip_static_module \
    --with-http_sub_module \
    --with-http_gunzip_module \
    --with-threads \
    --with-compat \
    --with-stream=dynamic \
    --with-http_ssl_module \
    # 优化双精度浮点数性能的编译选项
    --with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_GC64 -DLUAJIT_ENABLE_LUA52COMPAT -O3 -march=native -mtune=native -flto -ffat-lto-objects -fomit-frame-pointer' \
    # 官方推荐：在configure中直接使用多核
    -j$(nproc) \
    && \
    make -j$(nproc) && \
    make install \
    && \
    # strip /usr/local/nginx/sbin/nginx
    # strip /usr/local/nginx/sbin/nginx && \
    # 修复路径：使用/etc/nginx而不是/usr/local/nginx
    strip /usr/sbin/nginx && \
    # 检查LuaJIT和lualib的实际安装位置
    ls -la /usr/local/luajit/bin/ /usr/local/luajit/lib/ /usr/local/lualib/ 2>/dev/null && \
    ls -la /etc/nginx/ 2>/dev/null && \
    # 只strip存在的文件，避免错误
    strip /usr/local/luajit/bin/luajit && \
    strip /usr/local/luajit/lib/libluajit-5.1.so.2 && \
    find /etc/nginx/modules -name '*.so' -exec strip {} \; && \
    find /usr/local/lualib -name '*.so' -exec strip {} \; \
    \
    && \
    \
    tree /tmp && \
    # upx --best --lzma $FILENAME 2>/dev/null || true
    # upx --best --lzma /usr/local/nginx/sbin/nginx && \
    upx --best --lzma /usr/sbin/nginx && \
    upx --best --lzma /usr/local/luajit/bin/luajit && \
    strip /usr/local/luajit/lib/libluajit-5.1.so.2 && \
    find /etc/nginx/modules -name '*.so' -exec strip {} \; && \
    find /usr/local/lualib -name '*.so' -exec strip {} \; \
    && echo "Done"

FROM alpine:latest

RUN apk add --no-cache libgcc

# 复制之前编译好的 openresty, luajit 等文件
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/local/luajit /usr/local/luajit
COPY --from=builder /usr/local/lualib /usr/local/lualib
COPY --from=builder /usr/sbin/nginx /usr/sbin/
COPY --from=builder /usr/local/bin/openresty /usr/local/bin/
COPY --from=builder /usr/local/luajit/bin/luajit /usr/local/bin/

# 如果openresty二进制文件不存在，从/etc/nginx复制
RUN if [ ! -f /usr/local/bin/openresty ]; then \
    ln -sf /etc/nginx/bin/openresty /usr/local/bin/openresty \
    echo "OpenResty binary not found, using nginx directly"; \
fi

# 确保luajit二进制文件存在
RUN if [ ! -f /usr/local/bin/luajit ]; then \
    find / -name luajit -type f 2>/dev/null | xargs -I {} ln -sf {} /usr/local/bin/luajit \
    echo "Luajit binary not found"; \
fi

# 软连接库路径等操作
RUN mkdir -p /usr/local/lib \
    && ln -sf /usr/local/luajit/lib/libluajit-5.1.so.2 /usr/local/lib/ \
    && ln -sf /usr/local/luajit/lib/libluajit-5.1.so.2.1.ROLLING /usr/local/lib/ \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

ENV PATH="/usr/sbin:/usr/local/bin:$PATH"
ENV LUA_PATH="/usr/local/lualib/?.lua;;"
ENV LUA_CPATH="/usr/local/lualib/?.so;;"
# 修复未定义变量警告，使用:-为空值提供默认值
ENV LD_LIBRARY_PATH="/usr/local/luajit/lib:${LD_LIBRARY_PATH:-}"

WORKDIR /etc/nginx

RUN mkdir -p /var/log/nginx && chown -R nobody:nobody /var/log/nginx /etc/nginx

USER nobody

CMD ["nginx", "-g", "daemon off;"]