#define HL_NAME(n) datachannel_##n

#include <hl.h>
#include <rtc/rtc.h>

typedef struct _hl_rtc_peerconnection hl_rtc_peerconnection;
struct _hl_rtc_peerconnection {
    void (*finalize)(hl_rtc_peerconnection*);
    int pc;
    vclosure* descCb;
    vclosure* candidateCb;
    vclosure* stateCb;
    vclosure* gatheringStateCb;

    // For datachannel
    vclosure* datachannelCb;
};

typedef struct _hl_rtc_datachannel hl_rtc_datachannel;
struct _hl_rtc_datachannel {
    void (*finalize)(hl_rtc_datachannel*);
    int dc;
    vclosure* openCb;
    vclosure* closedCb;
    vclosure* errCb;
    vclosure* msgCb;
    vclosure* bufferLowCb;
};

typedef struct _callback_result callback_result;
struct _callback_result {
    vclosure** closure;
    vdynamic arg1;
    vdynamic arg2;
    int args;
    int arg1Size;
    int arg2Size;
    callback_result* next;
    const char* callback_name;
};

typedef struct _datachannel_callback datachannel_callback;
struct _datachannel_callback {
    int dc;
    hl_rtc_peerconnection* pc;
    datachannel_callback* next;
};

hl_mutex* callback_result_mutex = NULL;
hl_semaphore* callback_result_semaphore = NULL;
hl_semaphore* datachannel_callbacks_semaphore = NULL;
callback_result* callback_results = NULL;
callback_result* callback_results_end = NULL;
datachannel_callback* datachannel_callbacks = NULL;
datachannel_callback* datachannel_callbacks_end = NULL;

callback_result* callback_result_alloc()
{
    if (callback_results_end == NULL)
    {
        callback_results_end = callback_results = (callback_result*)malloc(sizeof(callback_result));
        callback_results_end->next = NULL;
    }
    else
    {
        callback_results_end->next = (callback_result*)malloc(sizeof(callback_result));
        callback_results_end = callback_results_end->next;
        callback_results_end->next = NULL;
    }
    return callback_results_end;
}

datachannel_callback* datachannel_callback_alloc()
{
    if (datachannel_callbacks_end == NULL)
    {
        datachannel_callbacks_end = datachannel_callbacks = (datachannel_callback*)malloc(sizeof(datachannel_callback));
        datachannel_callbacks_end->next = NULL;
    }
    else
    {
        datachannel_callbacks_end->next = (datachannel_callback*)malloc(sizeof(datachannel_callback));
        datachannel_callbacks_end = datachannel_callbacks_end->next;
        datachannel_callbacks_end->next = NULL;
    }
    return datachannel_callbacks_end;
}

void hl_rtc_peerconnection_finalize(hl_rtc_peerconnection* pc)
{
    rtcSetLocalCandidateCallback(pc->pc, NULL);
    rtcSetLocalDescriptionCallback(pc->pc, NULL);
    rtcSetLocalCandidateCallback(pc->pc, NULL);
    rtcSetStateChangeCallback(pc->pc, NULL);
    rtcSetGatheringStateChangeCallback(pc->pc, NULL);
    rtcDeletePeerConnection(pc->pc);
    hl_remove_root(&pc->candidateCb);
    hl_remove_root(&pc->datachannelCb);
    hl_remove_root(&pc->descCb);
    hl_remove_root(&pc->gatheringStateCb);
    hl_remove_root(&pc->stateCb);
}

void hl_rtc_datachannel_finalize(hl_rtc_datachannel* dc)
{
    rtcSetOpenCallback(dc->dc, NULL);
    rtcSetClosedCallback(dc->dc, NULL);
    rtcSetErrorCallback(dc->dc, NULL);
    rtcSetMessageCallback(dc->dc, NULL);
    rtcSetBufferedAmountLowCallback(dc->dc, NULL);
    rtcDeleteDataChannel(dc->dc);
    hl_remove_root(&dc->bufferLowCb);
    hl_remove_root(&dc->closedCb);
    hl_remove_root(&dc->errCb);
    hl_remove_root(&dc->msgCb);
    hl_remove_root(&dc->openCb);
}

static void RTC_API descriptionCallback(int pc, const char* sdp, const char* type, void* ptr);
static void RTC_API candidateCallback(int pc, const char* cand, const char* mid, void* ptr);
static void RTC_API stateChangeCallback(int pc, rtcState state, void* ptr);
static void RTC_API gatheringStateCallback(int pc, rtcGatheringState state, void* ptr);
static void RTC_API openCallback(int id, void* ptr);
static void RTC_API closedCallback(int id, void* ptr);
static void RTC_API errorCallback(int id, const char*, void* ptr);
static void RTC_API messageCallback(int id, const char* message, int size, void* ptr);
static void RTC_API bufferedAmountLowCallback(int id, void* ptr);
static void RTC_API dataChannelCallback(int pc, int dc, void* ptr);

#define _TPC _ABSTRACT(hl_rtc_peerconnection)
#define _TDC _ABSTRACT(hl_rtc_datachannel)

HL_PRIM void HL_NAME(initialize)()
{
    if (callback_result_mutex == NULL) 
    {
        callback_result_mutex = hl_mutex_alloc(false);
        hl_add_root(&callback_result_mutex);
    }

    if (callback_result_semaphore == NULL)
    {
        callback_result_semaphore = hl_semaphore_alloc(0);
        hl_add_root(&callback_result_semaphore);
    }

    if (datachannel_callbacks_semaphore == NULL)
    {
        datachannel_callbacks_semaphore = hl_semaphore_alloc(0);
        hl_add_root(&datachannel_callbacks_semaphore);
    }
}

HL_PRIM void HL_NAME(finalize)()
{
    if (callback_result_mutex != NULL)
    {
        hl_remove_root(&callback_result_mutex);
        hl_mutex_free(callback_result_mutex);
        callback_result_mutex = 0;
    }

    if (callback_result_semaphore != NULL)
    {
        hl_remove_root(&callback_result_semaphore);
        hl_semaphore_free(callback_result_semaphore);
        callback_result_semaphore = NULL;
    }

    if (datachannel_callbacks_semaphore != NULL)
    {
        hl_remove_root(&datachannel_callbacks_semaphore);
        hl_semaphore_free(datachannel_callbacks_semaphore);
        datachannel_callbacks_semaphore = NULL;
    }
}

HL_PRIM hl_rtc_peerconnection* HL_NAME(create_peer_connection)(varray* iceServers, vstring* bindAddress, int portBegin, int portEnd, int mtu, int maxMessageSize)
{
    rtcConfiguration conf;
    memset(&conf, 0, sizeof(conf));
    const char** iceServersMem = (const char**)hl_gc_alloc_raw(sizeof(char*) * iceServers->size);
    for (int i = 0; i < iceServers->size; i++) {
        vbyte* iceServer = hl_aptr(iceServers, vbyte*)[i];
        iceServersMem[i] = (char*)iceServer;
    }
    conf.iceServers = iceServersMem;
    conf.iceServersCount = iceServers->size;
    conf.bindAddress = hl_to_utf8(bindAddress->bytes);
    conf.portRangeBegin = portBegin;
    conf.portRangeEnd = portEnd;
    conf.mtu = mtu;
    conf.maxMessageSize = maxMessageSize;
    int pc = rtcCreatePeerConnection(&conf);
    hl_rtc_peerconnection* hlpc = (hl_rtc_peerconnection*)hl_gc_alloc_finalizer(sizeof(hl_rtc_peerconnection));
    hlpc->finalize = hl_rtc_peerconnection_finalize;
    hlpc->pc = pc;
    hlpc->candidateCb = NULL;
    hlpc->datachannelCb = NULL;
    hlpc->descCb = NULL;
    hlpc->gatheringStateCb = NULL;
    hlpc->stateCb = NULL;
    hl_add_root(&hlpc->candidateCb);
    hl_add_root(&hlpc->datachannelCb);
    hl_add_root(&hlpc->descCb);
    hl_add_root(&hlpc->gatheringStateCb);
    hl_add_root(&hlpc->stateCb);
    rtcSetUserPointer(pc, hlpc);
    rtcSetLocalDescriptionCallback(pc, descriptionCallback);
    rtcSetLocalCandidateCallback(pc, candidateCallback);
    rtcSetStateChangeCallback(pc, stateChangeCallback);
    rtcSetGatheringStateChangeCallback(pc, gatheringStateCallback);
    return hlpc;
}

HL_PRIM void HL_NAME(close_peer_connection)(hl_rtc_peerconnection* pc)
{
    rtcClosePeerConnection(pc->pc);
}

HL_PRIM void HL_NAME(set_peer_connection_callbacks)(hl_rtc_peerconnection* pc, vclosure* descCb, vclosure* candidateCb, vclosure* stateCb, vclosure* gatheringStateCb)
{
    pc->descCb = descCb;
    pc->candidateCb = candidateCb;
    pc->stateCb = stateCb;
    pc->gatheringStateCb = gatheringStateCb;
}

HL_PRIM void HL_NAME(set_remote_description)(hl_rtc_peerconnection* pc, vbyte* desc, vstring* type) 
{
    char* typestr = hl_to_utf8(type->bytes);
    if (strcmp(typestr, "offer") == 0) {
        rtcSetRemoteDescription(pc->pc, (const char*)desc, "offer");
    }
    if (strcmp(typestr, "answer") == 0) {
        rtcSetRemoteDescription(pc->pc, (const char*)desc, "answer");
    }
}

HL_PRIM void HL_NAME(add_remote_candidate)(hl_rtc_peerconnection* pc, vbyte* candidate)
{
    rtcAddRemoteCandidate(pc->pc, (const char*)candidate, NULL);
}

HL_PRIM hl_rtc_datachannel* HL_NAME(create_datachannel)(hl_rtc_peerconnection* pc, vstring* name)
{
    char* namestr = hl_to_utf8(name->bytes);
    int dc = rtcCreateDataChannel(pc->pc, namestr);
    hl_rtc_datachannel* hldc = (hl_rtc_datachannel*)hl_gc_alloc_finalizer(sizeof(hl_rtc_datachannel));
    hldc->finalize = hl_rtc_datachannel_finalize;
    hldc->dc = dc;
    hldc->openCb = NULL;
    hldc->closedCb = NULL;
    hldc->errCb = NULL;
    hldc->msgCb = NULL;
    hldc->bufferLowCb = NULL;
    hl_add_root(&hldc->bufferLowCb);
    hl_add_root(&hldc->closedCb);
    hl_add_root(&hldc->errCb);
    hl_add_root(&hldc->msgCb);
    hl_add_root(&hldc->openCb);
    rtcSetUserPointer(dc, hldc); // It gets messed up so we need to re-set it
    rtcSetOpenCallback(dc, openCallback);
    rtcSetClosedCallback(dc, closedCallback);
    rtcSetErrorCallback(dc, errorCallback);
    rtcSetMessageCallback(dc, messageCallback);
    rtcSetBufferedAmountLowCallback(dc, bufferedAmountLowCallback);
    return hldc;
}

HL_PRIM hl_rtc_datachannel* HL_NAME(create_datachannel_ex)(hl_rtc_peerconnection* pc, vstring* name, bool unordered, int maxRetransmits, int maxLifetime)
{
    char* namestr = hl_to_utf8(name->bytes);
    rtcDataChannelInit dcInit;
    memset(&dcInit, 0, sizeof(rtcDataChannelInit));
    dcInit.reliability.unordered = unordered;
    dcInit.reliability.maxPacketLifeTime = maxLifetime;
    dcInit.reliability.maxRetransmits = maxRetransmits;
    int dc = rtcCreateDataChannelEx(pc->pc, namestr, &dcInit);
    hl_rtc_datachannel* hldc = (hl_rtc_datachannel*)hl_gc_alloc_finalizer(sizeof(hl_rtc_datachannel));
    hldc->finalize = hl_rtc_datachannel_finalize;
    hldc->dc = dc;
    hldc->openCb = NULL;
    hldc->closedCb = NULL;
    hldc->errCb = NULL;
    hldc->msgCb = NULL;
    hldc->bufferLowCb = NULL;
    hl_add_root(&hldc->bufferLowCb);
    hl_add_root(&hldc->closedCb);
    hl_add_root(&hldc->errCb);
    hl_add_root(&hldc->msgCb);
    hl_add_root(&hldc->openCb);
    rtcSetUserPointer(dc, hldc); // It gets messed up so we need to re-set it
    rtcSetOpenCallback(dc, openCallback);
    rtcSetClosedCallback(dc, closedCallback);
    rtcSetErrorCallback(dc, errorCallback);
    rtcSetMessageCallback(dc, messageCallback);
    rtcSetBufferedAmountLowCallback(dc, bufferedAmountLowCallback);
    return hldc;
}

HL_PRIM void HL_NAME(set_peerconnection_datachannel_cb)(hl_rtc_peerconnection* pc, vclosure* openCb)
{
    rtcSetDataChannelCallback(pc->pc, dataChannelCallback);
    pc->datachannelCb = openCb;
}

HL_PRIM void HL_NAME(set_datachannel_callbacks)(hl_rtc_datachannel* dc, vclosure* openCb, vclosure* closeCb, vclosure* errorCb, vclosure* msgCb, vclosure* bufferLowCb)
{
    dc->openCb = openCb;
    dc->closedCb = closeCb;
    dc->errCb = errorCb;
    dc->msgCb = msgCb;
    dc->bufferLowCb = bufferLowCb;
}

HL_PRIM void HL_NAME(datachannel_send_message)(hl_rtc_datachannel* dc, vbyte* bytes, int len)
{
    rtcSendMessage(dc->dc, (const char*)bytes, len);
}

HL_PRIM vdynobj* HL_NAME(get_datachannel_reliability)(hl_rtc_datachannel* dc)
{
    rtcReliability r;
    rtcGetDataChannelReliability(dc->dc, &r);
    vdynamic* obj = (vdynamic*)hl_alloc_dynobj();
    hl_dyn_seti(obj, hl_hash_utf8("unordered"), &hlt_bool, r.unordered);
    hl_dyn_seti(obj, hl_hash_utf8("maxRetransmits"), &hlt_i32, r.maxRetransmits);
    hl_dyn_seti(obj, hl_hash_utf8("maxLifetime"), &hlt_i32, r.maxPacketLifeTime);
    return (vdynobj*)obj;
}

HL_PRIM vbyte* HL_NAME(get_local_address)(hl_rtc_peerconnection* pc)
{
    char buf[256];
    int buflen = rtcGetLocalAddress(pc->pc, buf, 256);
    if (buflen > 0)
    {
        vbyte* mem = (vbyte*)hl_gc_alloc_noptr(buflen);
        memcpy(mem, buf, buflen);
        return mem;
    }
    else
    {
        return NULL;
    }
}

HL_PRIM vbyte* HL_NAME(get_remote_address)(hl_rtc_peerconnection* pc)
{
    char buf[256];
    int buflen = rtcGetRemoteAddress(pc->pc, buf, 256);
    if (buflen > 0)
    {
        vbyte* mem = (vbyte*)hl_gc_alloc_noptr(buflen);
        memcpy(mem, buf, buflen);
        return mem;
    }
    else
    {
        return NULL;
    }
}

HL_PRIM int HL_NAME(get_buffered_amount)(hl_rtc_datachannel* dc)
{
    return rtcGetBufferedAmount(dc->dc);
}

HL_PRIM void HL_NAME(set_buffered_amount_low_threshold)(hl_rtc_datachannel* dc, int amt)
{
    rtcSetBufferedAmountLowThreshold(dc->dc, amt);
}

HL_PRIM void HL_NAME(process_events)()
{
    bool looped = false;
    while (datachannel_callbacks != NULL)
    {
        datachannel_callback* res = datachannel_callbacks;

        hl_mutex_acquire(callback_result_mutex);
        hl_rtc_datachannel* hldc = (hl_rtc_datachannel*)hl_gc_alloc_finalizer(sizeof(hl_rtc_datachannel));
        hldc->finalize = hl_rtc_datachannel_finalize;
        hldc->dc = res->dc;
        hldc->openCb = NULL;
        hldc->closedCb = NULL;
        hldc->errCb = NULL;
        hldc->msgCb = NULL;
        hldc->bufferLowCb = NULL;
        hl_add_root(&hldc->bufferLowCb);
        hl_add_root(&hldc->closedCb);
        hl_add_root(&hldc->errCb);
        hl_add_root(&hldc->msgCb);
        hl_add_root(&hldc->openCb);
        rtcSetUserPointer(res->dc, hldc); // It gets messed up so we need to re-set it
        rtcSetOpenCallback(res->dc, openCallback);
        rtcSetClosedCallback(res->dc, closedCallback);
        rtcSetErrorCallback(res->dc, errorCallback);
        rtcSetMessageCallback(res->dc, messageCallback);
        rtcSetBufferedAmountLowCallback(res->dc, bufferedAmountLowCallback);

        vdynamic* args[2];
        vdynamic pcarg;
        pcarg.t = res->pc->datachannelCb->t->fun->args[0]; // same type as hl_rtc_datachannel
        pcarg.v.ptr = hldc;
        args[0] = &pcarg;

        char buffer[256];
        // printf("handling callback: onDatachannel\n");
        if (rtcGetDataChannelLabel(hldc->dc, buffer, 256) >= 0)
        {
            vdynamic arg;
            arg.t = &hlt_bytes;
            arg.v.bytes = (vbyte*)hl_gc_alloc_noptr(256);
            memcpy(arg.v.bytes, buffer, 256);

            args[1] = &arg;
            hl_dyn_call(res->pc->datachannelCb, args, 2);
        }
        else
        {
            vdynamic arg;
            arg.t = &hlt_bytes;
            arg.v.bytes = (vbyte*)hl_gc_alloc_noptr(8);
            memcpy(arg.v.bytes, "unnamed", 8);

            args[1] = &arg;
            hl_dyn_call(res->pc->datachannelCb, args, 2);
        }

        
        datachannel_callbacks = datachannel_callbacks->next;
        free(res);
        hl_mutex_release(callback_result_mutex);

        looped = true;
    }
    if (looped) 
    {
        hl_mutex_acquire(callback_result_mutex);
        datachannel_callbacks_end = NULL;
        hl_mutex_release(callback_result_mutex);
    }
    looped = false;
    while (callback_results != NULL)
    {
        callback_result* res = callback_results;

        if (hl_semaphore_try_acquire(callback_result_semaphore, NULL))
        {
            hl_mutex_acquire(callback_result_mutex);
            vdynamic* args[2];
            vdynamic arg1 = res->arg1;
            vdynamic arg2 = res->arg2;
            if (res->args >= 1 && res->arg1.t == &hlt_bytes)
            {
                arg1.v.bytes = (vbyte*)hl_gc_alloc_noptr(res->arg1Size);
                memcpy(arg1.v.bytes, res->arg1.v.bytes, res->arg1Size);
                free(res->arg1.v.bytes);
            }
            if (res->args >= 2 && res->arg2.t == &hlt_bytes)
            {
                arg2.v.bytes = (vbyte*)hl_gc_alloc_noptr(res->arg2Size);
                memcpy(arg2.v.bytes, res->arg2.v.bytes, res->arg2Size);
                free(res->arg2.v.bytes);
            }
            // printf("handling callback: %s\n", res->callback_name);
            if (res->closure != NULL)
            {
                switch (res->args)
                {
                case 0:
                    hl_dyn_call(*res->closure, NULL, 0);
                    break;

                case 1:
                    args[0] = &arg1;
                    hl_dyn_call(*res->closure, args, 1);
                    break;

                case 2:
                    args[0] = &arg1;
                    args[1] = &arg2;
                    hl_dyn_call(*res->closure, args, 2);
                    break;
                }
            }

            callback_results = callback_results->next;
            free(res);
            hl_mutex_release(callback_result_mutex);

            looped = true;
        }
        else
            break;
    }
    if (looped)
    {
        hl_mutex_acquire(callback_result_mutex);
        callback_results_end = NULL;
        hl_mutex_release(callback_result_mutex);
    }
}

static void RTC_API descriptionCallback(int pc, const char* sdp, const char* type, void* ptr) 
{
    hl_rtc_peerconnection* hlpc = (hl_rtc_peerconnection*)ptr;

    int sdpLen = strlen(sdp);
    vbyte* b1 = (vbyte*)malloc(sdpLen + 1); // hl_gc_alloc_noptr(sdpLen + 1);
    memcpy(b1, sdp, sdpLen);
    b1[sdpLen] = '\0';

    int typeLen = strlen(type);
    vbyte* b2 = (vbyte*)malloc(typeLen + 1); // hl_gc_alloc_noptr(typeLen + 1);
    memcpy(b2, type, typeLen);
    b2[typeLen] = '\0';

    hl_mutex_acquire(callback_result_mutex);
    callback_result* res = callback_result_alloc();
    res->arg1.t = &hlt_bytes;
    res->arg1.v.bytes = b1;
    res->arg2.t = &hlt_bytes;
    res->arg2.v.bytes = b2;
    res->closure = &hlpc->descCb;
    res->args = 2;
    res->arg1Size = sdpLen + 1;
    res->arg2Size = typeLen + 1;
    res->callback_name = "onDescription";
    hl_semaphore_release(callback_result_semaphore);
    hl_mutex_release(callback_result_mutex);
}

static void RTC_API candidateCallback(int pc, const char* cand, const char* mid, void* ptr)
{
    hl_rtc_peerconnection* hlpc = (hl_rtc_peerconnection*)ptr;

    int sdpLen = strlen(cand);
    vbyte* b1 = (vbyte*)malloc(sdpLen + 1); // hl_gc_alloc_noptr(sdpLen + 1);
    memcpy(b1, cand, sdpLen);
    b1[sdpLen] = '\0';

    hl_mutex_acquire(callback_result_mutex);
    callback_result* res = callback_result_alloc();
    res->arg1.t = &hlt_bytes;
    res->arg1.v.bytes = b1;
    res->closure = &hlpc->candidateCb;
    res->args = 1;
    res->arg1Size = sdpLen + 1;
    res->callback_name = "onCandidate";
    hl_semaphore_release(callback_result_semaphore);
    hl_mutex_release(callback_result_mutex);
}

static void RTC_API stateChangeCallback(int pc, rtcState state, void* ptr) 
{
    hl_rtc_peerconnection* hlpc = (hl_rtc_peerconnection*)ptr;

    hl_mutex_acquire(callback_result_mutex);
    callback_result* res = callback_result_alloc();
    res->arg1.t = &hlt_i32;
    res->arg1.v.i = state;
    res->closure = &hlpc->stateCb;
    res->args = 1;
    res->callback_name = "onStateChange";
    hl_semaphore_release(callback_result_semaphore);
    hl_mutex_release(callback_result_mutex);
}

static void RTC_API gatheringStateCallback(int pc, rtcGatheringState state, void* ptr)
{
    hl_rtc_peerconnection* hlpc = (hl_rtc_peerconnection*)ptr;

    hl_mutex_acquire(callback_result_mutex);
    callback_result* res = callback_result_alloc();
    res->arg1.t = &hlt_i32;
    res->arg1.v.i = state;
    res->closure = &hlpc->gatheringStateCb;
    res->args = 1;
    res->callback_name = "onGatheringStateChange";
    hl_semaphore_release(callback_result_semaphore);
    hl_mutex_release(callback_result_mutex);
}

static void RTC_API openCallback(int id, void* ptr) 
{
    hl_rtc_datachannel* hldc = (hl_rtc_datachannel*)ptr;
    if (hldc->openCb == NULL) return;
    char buffer[256];
    if (rtcGetDataChannelLabel(hldc->dc, buffer, 256) >= 0) 
    {
        hl_mutex_acquire(callback_result_mutex);
        callback_result* res = callback_result_alloc();
        res->arg1.t = &hlt_bytes;
        res->arg1.v.bytes = (vbyte*)malloc(256);
        memcpy(res->arg1.v.bytes, buffer, 256);
        res->arg1Size = 256;
        res->closure = &hldc->openCb;
        res->args = 1;
        res->callback_name = "onOpen";
        hl_semaphore_release(callback_result_semaphore);
        hl_mutex_release(callback_result_mutex);
    }
    else 
    {
        hl_mutex_acquire(callback_result_mutex);
        callback_result* res = callback_result_alloc();
        res->arg1.t = &hlt_bytes;
        res->arg1.v.bytes = (vbyte*)malloc(8);
        memcpy(res->arg1.v.bytes, "unnamed", 8);
        res->arg1Size = 8;
        res->closure = &hldc->openCb;
        res->args = 1;
        res->callback_name = "onOpen";
        hl_semaphore_release(callback_result_semaphore);
        hl_mutex_release(callback_result_mutex);
    }
}

static void RTC_API closedCallback(int id, void* ptr)
{
    hl_rtc_datachannel* hldc = (hl_rtc_datachannel*)ptr;

    hl_mutex_acquire(callback_result_mutex);
    callback_result* res = callback_result_alloc();
    res->closure = &hldc->closedCb;
    res->args = 0;
    res->callback_name = "onClose";
    hl_semaphore_release(callback_result_semaphore);
    hl_mutex_release(callback_result_mutex);
}

static void RTC_API errorCallback(int id, const char* error, void* ptr) 
{
    hl_rtc_datachannel* hldc = (hl_rtc_datachannel*)ptr;
    int errorlen = strlen(error);

    hl_mutex_acquire(callback_result_mutex);
    callback_result* res = callback_result_alloc();
    res->arg1.t = &hlt_bytes;
    res->arg1.v.bytes = (vbyte*)malloc(errorlen + 1);
    memcpy(res->arg1.v.bytes, error, errorlen);
    res->arg1Size = errorlen + 1;
    res->closure = &hldc->errCb;
    res->args = 1;
    res->callback_name = "onError";
    hl_semaphore_release(callback_result_semaphore);
    hl_mutex_release(callback_result_mutex);
}

static void RTC_API messageCallback(int id, const char* message, int size, void* ptr) 
{
    hl_rtc_datachannel* hldc = (hl_rtc_datachannel*)ptr;

    if (size < 0) // negative size indicates a null-terminated string
    { 
        int len = strlen(message);

        hl_mutex_acquire(callback_result_mutex);
        callback_result* res = callback_result_alloc();
        res->arg1.t = &hlt_bytes;
        res->arg1.v.bytes = (vbyte*)malloc(len);
        memcpy(res->arg1.v.bytes, message, len);
        res->arg1.v.bytes[len] = '\0';
        res->arg1Size = len + 1;
        res->arg2.t = &hlt_i32;
        res->arg2.v.i = len + 1;
        res->closure = &hldc->msgCb;
        res->args = 2;
        res->callback_name = "onMessage";
        hl_semaphore_release(callback_result_semaphore);
        hl_mutex_release(callback_result_mutex);
    }
    else 
    {
        hl_mutex_acquire(callback_result_mutex);
        callback_result* res = callback_result_alloc();
        res->arg1.t = &hlt_bytes;
        res->arg1.v.bytes = (vbyte*)malloc(size);
        memcpy(res->arg1.v.bytes, message, size);
        res->arg1Size = size;
        res->arg2.t = &hlt_i32;
        res->arg2.v.i = size;
        res->closure = &hldc->msgCb;
        res->args = 2;
        res->callback_name = "onMessage";
        hl_semaphore_release(callback_result_semaphore);
        hl_mutex_release(callback_result_mutex);
    }
}

static void RTC_API dataChannelCallback(int pc, int dc, void* ptr)
{
    hl_rtc_peerconnection* hlpc = (hl_rtc_peerconnection*)ptr;
 

    hl_mutex_acquire(callback_result_mutex);
    datachannel_callback* res = datachannel_callback_alloc();
    res->dc = dc;
    res->pc = hlpc;
    hl_mutex_release(callback_result_mutex);
}

static void RTC_API bufferedAmountLowCallback(int dc, void* ptr)
{
    hl_rtc_datachannel* hldc = (hl_rtc_datachannel*)ptr; 

    hl_mutex_acquire(callback_result_mutex);
    callback_result* res = callback_result_alloc();
    res->closure = &hldc->bufferLowCb;
    res->args = 0;
    res->callback_name = "onBufferLow";
    hl_semaphore_release(callback_result_semaphore);
    hl_mutex_release(callback_result_mutex);
}

DEFINE_PRIM(_VOID, initialize, _NO_ARG);
DEFINE_PRIM(_VOID, finalize, _NO_ARG);
DEFINE_PRIM(_VOID, process_events, _NO_ARG);
DEFINE_PRIM(_TPC, create_peer_connection, _ARR _STRING _I32 _I32 _I32 _I32);
DEFINE_PRIM(_VOID, close_peer_connection, _TPC);
DEFINE_PRIM(_VOID, set_peer_connection_callbacks, _TPC _FUN(_VOID, _BYTES _BYTES) _FUN(_VOID, _BYTES) _FUN(_VOID, _I32) _FUN(_VOID, _I32));
DEFINE_PRIM(_VOID, set_remote_description, _TPC _BYTES _STRING);
DEFINE_PRIM(_VOID, add_remote_candidate, _TPC _BYTES);
DEFINE_PRIM(_TDC, create_datachannel, _TPC _STRING);
DEFINE_PRIM(_TDC, create_datachannel_ex, _TPC _STRING _BOOL _I32 _I32);
DEFINE_PRIM(_VOID, set_peerconnection_datachannel_cb, _TPC _FUN(_VOID, _TDC _BYTES));
DEFINE_PRIM(_VOID, set_datachannel_callbacks, _TDC  _FUN(_VOID, _BYTES) _FUN(_VOID, _NO_ARG) _FUN(_VOID, _BYTES) _FUN(_VOID, _BYTES _I32) _FUN(_VOID, _NO_ARG));
DEFINE_PRIM(_VOID, datachannel_send_message, _TDC _BYTES _I32);
DEFINE_PRIM(_DYN, get_datachannel_reliability, _TDC);
DEFINE_PRIM(_BYTES, get_local_address, _TPC);
DEFINE_PRIM(_BYTES, get_remote_address, _TPC);
DEFINE_PRIM(_I32, get_buffered_amount, _TDC);
DEFINE_PRIM(_VOID, set_buffered_amount_low_threshold, _TDC _I32)