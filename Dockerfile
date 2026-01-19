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
    # cd openresty-${OPENRESTY_VERSION} && \
    # ./configure \
    #   --prefix=/etc/openresty \
    #   --user=root \
    #   --group=root \
    #   --with-cc-opt="-static -static-libgcc" \
    #   --with-ld-opt="-static" \
    #   --with-openssl=../openssl-${OPENSSL_VERSION} \
    #   --with-zlib=../zlib-${ZLIB_VERSION} \
    #   --with-pcre \
    #   --with-pcre-jit \
    #   --with-http_ssl_module \
    #   --with-http_v2_module \
    #   --with-http_gzip_static_module \
    #   --with-http_stub_status_module \
    #   --without-http_rewrite_module \
    #   --without-http_auth_basic_module \
    #   --with-threads && \
    # make -j$(nproc) && \
    # make install \
  
    cd openresty-${OPENRESTY_VERSION} && \
    # 申明两个模块路径
    export ZSTD_INC=/usr/local/zstd/include && \
    export ZSTD_LIB=/usr/local/zstd/lib && \
    ./configure \
    --prefix=/usr/local \
    --modules-path=/usr/local/nginx/modules \
    --sbin-path=/usr/local/nginx/sbin/nginx \
    --conf-path=/usr/local/nginx/conf/nginx.conf \
    --error-log-path=/usr/local/nginx/logs/error.log \
    --http-log-path=/usr/local/nginx/logs/access.log \
    # --with-cc-opt="-static -O3 -DNGX_LUA_ABORT_AT_PANIC -static-libgcc" \
    # --with-ld-opt="-static -Wl,--export-dynamic" \
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
    # --with-debug \
    # --with-lua_resty_core \
    # --with-lua_resty_lrucache \
    # --with-lua_resty_lock \
    # --without-lua_resty_dns \
    # --without-lua_resty_memcached \
    # --without-lua_redis_parser \
    # --without-lua_rds_parser \
    # --without-lua_resty_redis \
    # --without-lua_resty_mysql \
    # --without-lua_resty_upload \
    # --without-lua_resty_upstream_healthcheck \
    # --without-lua_resty_string \
    # --without-lua_resty_websocket \
    # --without-lua_resty_limit_traffic \
    # --without-lua_resty_lrucache \
    # --without-lua_resty_lock \
    # --without-lua_resty_signal \
    # --without-lua_resty_lrucache \
    # --without-lua_resty_shell \
    # --without-lua_resty_core \
    # --without-select_module \
    # --without-lua_resty_mysql \
    # --without-http_charset_module \
    # --without-http_ssi_module \
    # --without-http_userid_module \
    # --without-http_auth_basic_module \
    # --without-http_mirror_module \
    # --without-http_autoindex_module \
    # --without-http_split_clients_module \
    # --without-http_memcached_module \
    # --without-http_empty_gif_module \
    # --without-http_browser_module \
    # --without-stream_limit_conn_module \
    # --without-stream_geo_module \
    # --without-stream_map_module \
    # --without-stream_split_clients_module \
    # --without-stream_return_module \
    # cd openresty-${OPENRESTY_VERSION} && \
    # ./configure \
    # --prefix=/usr/local/openresty \
    # --with-luajit \
    # --with-pcre-jit \
    # --with-ipv6 \
    # --with-http_ssl_module \
    # --with-http_realip_module \
    # --with-http_addition_module \
    # --with-http_sub_module \
    # --with-http_dav_module \
    # --with-http_flv_module \
    # --with-http_mp4_module \
    # --with-http_gunzip_module \
    # --with-http_gzip_static_module \
    # --with-http_auth_request_module \
    # --with-http_random_index_module \
    # --with-http_secure_link_module \
    # --with-http_stub_status_module \
    # --with-http_v2_module \
    # --with-stream \
    # --with-stream_ssl_module \
    # --with-stream_ssl_preread_module \
    # --with-stream_realip_module \
    # --with-threads \
    # --with-file-aio
    && \
    make -j$(nproc) && \
    make install \
    && \
    # strip /usr/local/nginx/sbin/nginx
    strip /usr/local/nginx/sbin/nginx && \
    strip /usr/local/luajit/bin/luajit || true && \
    strip /usr/local/luajit/lib/libluajit-5.1.so.2 || true && \
    find /usr/local/nginx/modules -name '*.so' -exec strip {} \; || true && \
    find /usr/local/lualib -name '*.so' -exec strip {} \; || true \
    \
    echo "Done"

FROM alpine:latest

RUN apk add --no-cache libgcc

# 复制之前编译好的 openresty, luajit 等文件
COPY --from=builder /usr/local/nginx /usr/local/nginx
COPY --from=builder /usr/local/luajit /usr/local/luajit
COPY --from=builder /usr/local/lualib /usr/local/lualib
COPY --from=builder /usr/local/bin/openresty /usr/local/bin/
COPY --from=builder /usr/local/luajit/bin/luajit /usr/local/bin/

# 软连接库路径等操作
RUN mkdir -p /usr/local/lib \
    && ln -sf /usr/local/luajit/lib/libluajit-5.1.so.2 /usr/local/lib/ \
    && ln -sf /usr/local/luajit/lib/libluajit-5.1.so.2.1.ROLLING /usr/local/lib/ \
    && ln -sf /dev/stdout /usr/local/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/nginx/logs/error.log

ENV PATH="/usr/local/nginx/sbin:/usr/local/bin:$PATH"
ENV LUA_PATH="/usr/local/lualib/?.lua;;"
ENV LUA_CPATH="/usr/local/lualib/?.so;;"
ENV LD_LIBRARY_PATH="/usr/local/luajit/lib:$LD_LIBRARY_PATH"

WORKDIR /usr/local/nginx

RUN mkdir -p /data/logs && chown -R nobody:nobody /data/logs /usr/local/nginx

USER nobody

CMD ["nginx", "-g", "daemon off;"]