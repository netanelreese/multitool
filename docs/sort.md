# Funnelsort Junk

## E GUY CODE

### buffer.h

```{c}
#ifndef INCLUDES_FUNNELSORT_BUFFER_H
#define INCLUDES_FUNNELSORT_BUFFER_H
struct Buffer { // FIFO queue
    void *data;
    size_t nmemb; // max count of elements
    size_t size;  // size of one element
    size_t head;
    size_t tail;
    size_t count; // current count of elements
};
#endif /* INCLUDES_FUNNELSORT_BUFFER_H */
```

### funnel.h

```{c}
#ifndef INCLUDES_FUNNELSORT_FUNNEL_H
#define INCLUDES_FUNNELSORT_FUNNEL_H
#include "buffer.h"
struct Funnel {
    struct Buffer **in; // input arrays represented as buffers
    size_t in_count; // count of input arrays (buffers)

    struct Buffer **buffers;
    struct Funnel **bottom;
    size_t bb_count; // count of bottom funnels = count of buffers

    size_t size; // size of one element
    struct Funnel *top;
    struct Buffer *out;
};
#endif /* INCLUDES_FUNNELSORT_FUNNEL_H */
```

### sort.h
```{c}
#ifndef INCLUDES_FUNNELSORT_SORT_H
#define INCLUDES_FUNNELSORT_SORT_H
#include <stddef.h>

typedef int (*cmp_t)(const void *, const void *);
void
sort(void *ptr, const size_t nmemb, const size_t size, const cmp_t cmp);

#endif /* INCLUDES_FUNNELSORT_SORT_H */
```

### sort.c

```{c}
#include <stdlib.h>
#include <string.h>
#include "sort.h"
#include <math.h>
#include <stdio.h>
#define M 128
#include "buffer.h"
#include "funnel.h"

void
print_buffer(struct Buffer *buffer, int shift)
{
    size_t i;
    printf("%*s" "%s\n", shift, " ", "Buffer");
    printf("%*s" "%s %d\n", shift+2, " ", "nmemb:", (int)buffer->nmemb);       
    printf("%*s" "%s %d\n", shift+2, " ", "head:", (int)buffer->head);       
    printf("%*s" "%s %d\n", shift+2, " ", "tail:", (int)buffer->tail);       
    printf("%*s" "%s %d\n", shift+2, " ", "count:", (int)buffer->count);       
    printf("%*s" "%s", shift+2, " ", "data: ");
    for (i=0; i<buffer->nmemb; i++) {
        printf("%d", (int)*(int*)(buffer->data + i*buffer->size));
        printf("%c", ' ');
    }
    printf("%s", "\n");
}


void
print_funnel(struct Funnel *funnel, int shift)
{
    if (funnel == NULL) {
        printf("%*s" "%s\n", shift+2, " ", "NULL");
        return;
    }
    printf("%*s" "\n%s\n", shift, " ", "***FUNNEL***");

    printf("%*s" "%s\n", shift+2, " ", "OUTPUT BUFFER");
    print_buffer(funnel->out, shift+2);

    printf("%*s" "%s\n", shift+2, " ", "TOP FUNNEL");
    print_funnel(funnel->top, shift+4);

    printf("INTERMEDIATE BUFFERS, BOTTOM FUNNELS:\n");    
    size_t i;
    for (i=0; i<funnel->bb_count; i++) {
        printf("%*s" "%s %d:\n", shift, " ", "intermediate buffer", (int)i);
        print_buffer(funnel->buffers[i], shift+2);

        printf("%*s" "%s %d:\n", shift, " ", "bottom funnel", (int)i);
        print_funnel(funnel->bottom[i], shift+4);        
    }

    printf("%*s" "%s\n", shift+2, " ", "INPUT BUFFERS:");
    for (i=0; i<funnel->in_count; i++) {
        print_buffer(funnel->in[i], shift+2);
    }
}


void
buffer_enqueue(struct Buffer* buffer, void *el)
{
    memcpy(buffer->data + buffer->size * buffer->tail, el, buffer->size);
    buffer->tail = (buffer->tail + 1) % buffer->nmemb;
    buffer->count++;
}


void *
buffer_dequeue(struct Buffer* buffer)
{
    size_t head = buffer->head;
    buffer->head = (buffer->head + 1) % buffer->nmemb;
    buffer->count--;
    return buffer->data + head * buffer->size;
}


int
buffer_empty(struct Buffer *buffer)
{
    return !buffer->count;
}


int
buffer_full(struct Buffer *buffer)
{
    return (buffer->count == buffer->nmemb);
}


int
buffers_nonempty(struct Buffer **in, size_t in_count)
{
    size_t i;
    for (i=0; i<in_count; i++) {
        if (buffer_empty(in[i])) {
           return 0;
        }
    }
    return 1;
}


int
buffers_empty(struct Buffer **in, size_t in_count)
{
    size_t i;
    for (i=0; i<in_count; i++) {
        if (!buffer_empty(in[i])) {
           return 0;
        }
    }
    return 1;
}


void *
buffer_head(struct Buffer *buffer)
{
    return buffer->data + buffer->head * buffer->size;
}


size_t
get_best_buffer_num(struct Buffer **in, size_t in_count, const cmp_t cmp)
{
    size_t i,j, best;
    for (i=0; i<in_count; i++) {        
        if (!buffer_empty(in[i])) {
            best = i;
            break;
        }
    }
    for (j=i+1; j<in_count; j++) {        
        if (!buffer_empty(in[j]) && cmp(buffer_head(in[j]), buffer_head(in[best])) < 0) {
            best = j;
        }
    }
    return best;
}


int
get_buffer_nmemb(const int bot_nmemb, const int top_nmemb)
{
    if (top_nmemb) {
        return 2 * pow(top_nmemb, 1.5);
    }
    else {
        return 2 * pow(bot_nmemb, 1.5);
    }
}


struct Buffer *
buffer_create(void *data, const size_t nmemb, const size_t size, const size_t head, const size_t tail, const size_t count)
{
    struct Buffer *buffer = (struct Buffer *)
               malloc(sizeof(struct Buffer));
    buffer->data = data;
    buffer->nmemb = nmemb;
    buffer->size = size;
    buffer->head = head;
    buffer->tail = tail;
    buffer->count = count;
    return buffer;
}


struct Buffer *
buffer_new(const size_t nmemb, const size_t size)
{ // create empty buffer (initialize FIFO queue)
    void *data = (void *) malloc(nmemb*size);
    return buffer_create(data, nmemb, size, 0, 0, 0);
}


struct Funnel *
funnel_new(struct Buffer **in, struct Buffer *out, const size_t size, const size_t in_count)
{
    struct Funnel *funnel = (struct Funnel *)
               malloc(sizeof(struct Funnel));
    funnel->in = in;
    funnel->in_count = in_count;
    funnel->out = out;
    funnel->size = size;
    if (in_count * size < M/4.0) { // maybe not M/4?
        funnel->bb_count = 0;
        funnel->bottom = NULL;
        funnel->top = NULL;
        return funnel;
    }
    int i;
    double root = sqrt(in_count);
    struct Buffer **curr = in;
    int froot = floor(root);

    if (froot*froot < (int)in_count) { // if in_count isn't square
        int croot = ceil(root);
        int big_count = in_count/(double)croot; // count buffers of size croot
        int rest = in_count - big_count*croot;
        int small_count = ceil(rest/froot); // count buffers of size froot
        int all_count = big_count + small_count; // size of top funnel
        int big_buff_nmemb   = get_buffer_nmemb(croot, all_count);
        int small_buff_nmemb = get_buffer_nmemb(froot, all_count);
        struct Buffer **buffers = (struct Buffer**)
                  malloc(sizeof(struct Buffer *)*all_count); // intermediate buffers

        struct Funnel **bfunnels = (struct Funnel **)
                  malloc(sizeof(struct Funnel *)*all_count); // bottom funnels

        for (i=0; i<big_count; i++) {
            buffers[i] = buffer_new(big_buff_nmemb, size);
            bfunnels[i] = funnel_new(curr, buffers[i], size, croot);             
            curr += croot;
        }

        for (i=big_count; i<all_count; i++) {
            buffers[i] = buffer_new(small_buff_nmemb, size);
            bfunnels[i] = funnel_new(curr, buffers[i], size, froot);             
            curr += croot;
        }

        funnel->bb_count = all_count;
        funnel->buffers = buffers;
        funnel->bottom = bfunnels;

        struct Funnel *tfunnel = (struct Funnel *)
                  malloc(sizeof(struct Funnel *));
        tfunnel = funnel_new(buffers, out, size, all_count);
        funnel->top = tfunnel;
    }
    else {
        funnel->bb_count = froot;
        struct Buffer **buffers = (struct Buffer**)
                  malloc(sizeof(struct Buffer *)*froot); // intermediate buffers

        struct Funnel **bfunnels = (struct Funnel **)
                  malloc(sizeof(struct Funnel *)*froot); // bottom funnels
        int buff_nmemb = 2 * pow(froot, 1.5);
        
        for (i=0; i<froot; i++) {
            buffers[i] = buffer_new(buff_nmemb, size);
            bfunnels[i] = funnel_new(curr, buffers[i], size, froot);
            curr += froot;
        }
        
        funnel->buffers = buffers;
        funnel->bottom = bfunnels;

        struct Funnel *tfunnel = (struct Funnel *)
                  malloc(sizeof(struct Funnel *));
        tfunnel = funnel_new(buffers, out, size, froot);
        funnel->top = tfunnel;
    }
    return funnel;
}


struct Buffer **
buffers_create(void *data, const size_t nmemb, const size_t size,
                                     const size_t count, const size_t len, const size_t extra)
{ // divide data into count (+extra) buffers
    
    struct Buffer **buffers = (struct Buffer **)malloc(sizeof(struct Buffer*)*(count + extra)); 
    size_t i, d = len*size;
    void *p = data;
    for (i=0; i<count; i++) {
        buffers[i] = buffer_create(p, len, size, 0, 0, len);
        p += d;
    }
    if (extra > 0) {
        size_t rest = nmemb - len * count;
        buffers[i] = buffer_create(p, rest, size, 0, 0, rest);
    }
    
    return buffers;
}


struct Funnel *
funnel_create(void *data, const size_t nmemb, const size_t size, const size_t count, const size_t len, const size_t extra)
{
    struct Buffer **in_buffers = buffers_create(data, nmemb, size, count, len, extra);
    struct Buffer *out_buffer = buffer_new(nmemb, size);
    return funnel_new(in_buffers, out_buffer, size, count+extra);
}


void
funnel_fill(struct Funnel *funnel, const cmp_t cmp)
{
    if (buffers_nonempty(funnel->in, funnel->in_count)) {
        while (!buffer_full(funnel->out)){// && !buffers_empty(funnel->in, funnel->in_count)) {
            size_t best_num = get_best_buffer_num(funnel->in, funnel->in_count, cmp);
            buffer_enqueue(funnel->out, buffer_dequeue(funnel->in[best_num])); 
/*	    need fill in?
            if (buffer_empty(funnel->in[best_num])) {
            }
*/
        }
    }
    else {
        return;
    }
}


void
funnel_warmup(struct Funnel *funnel, const cmp_t cmp)
{
    if (funnel->bb_count) {
        size_t i;
        for (i=0; i<funnel->bb_count; i++) {
            funnel_warmup(funnel->bottom[i], cmp);
        }
    }
    funnel_fill(funnel, cmp);
}


void
sort(void *ptr, const size_t nmemb, const size_t size, const cmp_t cmp)
{
    if (nmemb * size < M/4) { // maybe not M/4?
        qsort(ptr, nmemb, size, cmp); 
    }
    else {
           int n = pow(nmemb, 1/3.0); // n = nmemb^(1/3), count of parts
           size_t len = nmemb / n; // nmemb in each part
           size_t d = len*size;
           void *p = ptr;
           int i;
           for (i=0; i<n; i++) {
               sort(p, len, size, cmp);
               p += d;
           }
           size_t extra = 0;
           size_t rest = nmemb - n * len;
           if (rest > 0) {
               sort(p, rest, size, cmp);
               extra++;
           }
          struct Funnel *funnel = funnel_create(ptr, nmemb, size, n, len, extra); 
//         ??  funnel_warmup(funnel, cmp);
          funnel_fill(funnel, cmp);
          memcpy(ptr, funnel->out->data, nmemb*size);
    } 
}
```

## P GUY CODE

### sort.h

```{c}
#ifndef INCLUDES_FUNNELSORT_SORT_H
#define INCLUDES_FUNNELSORT_SORT_H
#include <stddef.h>

enum {FUNNEL_EXHAUSTED = 1, FUNNEL_NOT_EMPTY = 2};

typedef int (*cmp_t)(const void *, const void *);

int compare_longlong(const void *a, const void *b);
int compare_short(const void *a, const void *b);

void
sort(void *ptr, size_t nmemb, size_t size, cmp_t cmp);

typedef struct funnel {
    struct funnel *lr[2];
    void *in;
    void *out;
    size_t size;
    size_t nmemb;
    size_t index;
    cmp_t cmp;
} funnel;

funnel *
funnel_create(void *in, void *out, size_t nmemb, size_t size, cmp_t cmp);

void
funnel_fill(funnel *f);

void funnel_sort(void *base, size_t nmemb, size_t size, cmp_t cmp);

#endif /* INCLUDES_FUNNELSORT_SORT_H */
```

### sort.c

```{c}
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "sort.h"
#define CACHELINE_SIZE 64

int compare_longlong(const void *a, const void *b) {
    return *(const unsigned long long *) a < *(const unsigned long long *) b ? -1 : 1;
}

int compare_short(const void *a, const void *b) {
    return *(const unsigned short *) a < *(const unsigned short *) b ? -1 : 1;
}

funnel *
funnel_create(void *in, void *out, size_t nmemb, size_t size, cmp_t cmp) {
    funnel *f = (funnel *)malloc(sizeof(funnel));

    f->out = out;
    f->nmemb = nmemb;
    f->size = size;
    f->cmp = cmp;
    f->in = in;
    f->index = 0;

    if ((f->nmemb) * size > CACHELINE_SIZE) {
        //fprintf(stdout, "Branches\n");
        size_t nmemb_left = nmemb / 2;
        size_t nmemb_right = nmemb - nmemb_left;
        void *out_left = malloc(nmemb_left * f->size);
        void *out_right = malloc(nmemb_right * f->size);        
        f->lr[0] = funnel_create(in, out_left, nmemb_left, f->size, cmp);
        f->lr[1] = funnel_create((char *) in + nmemb_left * size, out_right, 
                      nmemb_right, f->size, cmp);
    } else {
        //fprintf(stdout, "Feel the bottom\n");
        f->lr[0] = f->lr[1] = NULL;
    }
    return f;
}

void
funnel_clean(funnel *f) {
    if (f) {
        if (f->out) {
            free(f->out);
        }
        if (f->lr[0]) {
            funnel_clean(f->lr[0]);
        }
        if (f->lr[1]) {
            funnel_clean(f->lr[1]);
        }
        free(f);
    }
}

void *
funnel_first(funnel *f) {
    if (f->index < f->nmemb) {
        return (void *) ((char *) f->out + f->size * f->index);
    }
    return NULL;  
}

int
funnel_pop(funnel *f) {
    f->index++;
    if (f->index >= f->nmemb) {
        // funnel_fill(f);
        return FUNNEL_EXHAUSTED;
    }
    return FUNNEL_NOT_EMPTY;
}
void
funnel_fill(funnel *f) {
    //size_t i1 = 0, i2 = 0;

    if (f->lr[0] == NULL || f->lr[1] == NULL) {
        qsort(f->in, f->nmemb, f->size, f->cmp);
        memcpy(f->out, f->in, f->nmemb * f->size);
        //free(f->in);
        return;
    }
    funnel_fill(f->lr[0]);
    funnel_fill(f->lr[1]);
    // perform merge
    size_t i1 = f->lr[0]->index, i2 = f->lr[1]->index;
    size_t n1 = f->lr[0]->nmemb, n2 = f->lr[1]->nmemb;
    void *e1, *e2;
    size_t index = 0;
    
    e1 = funnel_first(f->lr[0]);
    e2 = funnel_first(f->lr[1]);
    while (i1 < n1 && i2 < n2) {
        //printf("CMP: %hu %zu %hu %zu\n", *(unsigned short *)e1,
        //        f->lr[0]->index, *(unsigned short *)e2, f->lr[1]->index);

        if (f->cmp(e1, e2) < 0) {
            memcpy((char *)f->out + index * f->size, e1, f->size);
            if (funnel_pop(f->lr[0]) == FUNNEL_EXHAUSTED) {
                //free(f->lr[0]->out);
            }
            e1 = funnel_first(f->lr[0]);
            i1++;        
        } else {
            memcpy((char *)f->out + index * f->size, e2, f->size);
            if (funnel_pop(f->lr[1]) == FUNNEL_EXHAUSTED) {
                //free(f->lr[1]->out);
            }
            e2 = funnel_first(f->lr[1]);
            i2++;
        }
        index++;
    }
    while (i1 < n1) {
        e1 = funnel_first(f->lr[0]);
        memcpy((char *)f->out + index * f->size, e1, f->size);
        if (funnel_pop(f->lr[0]) == FUNNEL_EXHAUSTED) {
            //free(f->lr[0]->out);
        }
        i1++;
        index++;
    }
    while (i2 < n2) {
        e2 = funnel_first(f->lr[1]);
        memcpy((char *)f->out + index * f->size, e2, f->size);
        if (funnel_pop(f->lr[1]) == FUNNEL_EXHAUSTED) {
            //free(f->lr[1]->out);
        }
        i2++;
        index++;
    }

    return; 
}


void funnel_sort(void *base, size_t nmemb, size_t size, cmp_t cmp) {
    void *out = malloc(size * nmemb);
    funnel *funn = funnel_create(base, out, nmemb, size, cmp);
    if (!funn) {
        fprintf(stdout, "Error while creation funnel\n");
        return;
    }
    funnel_fill(funn);
    memcpy(base, out, size * nmemb);
    funnel_clean(funn);
}
```

## Golang lazy funnelsort

### funnelsort.go

```{go}
// Package funnelsort implements lazy funnel sort, a cache-oblivious
// sorting algorithm.
//
//     http://courses.csail.mit.edu/6.851/spring12/lectures/L09.html
//     http://www.cs.amherst.edu/~ccm/cs34/papers/a2_2-brodal.pdf
//
package funnelsort

import (
	"math"
	"sort"
	"syscall"
)

type Item interface {
	Less(b Item) bool
	Bytes() []byte
}

// Function funnelsort uses to create a new item from a slice of
// bytes. The function must be set before calling FunnelSort.
var NewItem func(b []byte) Item

// The maximum length of an item in bytes.
var MaxItemLength = 4096

type Reader interface {
	Read() Item
}

type Writer interface {
	Write(i Item)
}

type Buffer interface {
	Reader
	Writer
	Peek() Item
	Empty() bool
	Full() bool
	Reset()
	Close()
}

type MBuffer struct {
	unread uint64
	buffer []byte
	off    int
}

func (b *MBuffer) Close() {
	b.unmap()
}

func (b *MBuffer) Empty() bool {
	return b.unread == 0
}

func (b *MBuffer) Full() bool {
	return len(b.buffer)+MaxItemLength >= cap(b.buffer)
}

func (b *MBuffer) Reset() {
	b.unread = 0
	b.buffer = b.buffer[0:0]
	b.off = 0
}

func (b *MBuffer) Write(a Item) {
	b.unread += 1
	// The following must hold: len(b.buffer) + len(a.Bytes()) <
	// cap(b.buffer) which is currently ensured via MaxItemLength
	b.buffer = append(b.buffer, a.Bytes()...)
}

func (b *MBuffer) Peek() (item Item) {
	if b.unread > 0 {
		item = NewItem(b.buffer[b.off:])
	}
	return
}

func (b *MBuffer) Read() (item Item) {
	if b.unread > 0 {
		b.unread -= 1
		item = NewItem(b.buffer[b.off:])
		b.off += len(item.Bytes())
	}
	return item
}

func (b *MBuffer) unmap() {
	if cap(b.buffer) > 0 {
		if err := syscall.Munmap(b.buffer[0:cap(b.buffer)]); err == nil {
			b.buffer = nil
		} else {
			panic(err)
		}
	}
}

func NewMBuffer(capacity int) (buffer *MBuffer) {
	if mmap, err := syscall.Mmap(-1, 0, capacity, syscall.PROT_READ|syscall.PROT_WRITE, syscall.MAP_ANON|syscall.MAP_PRIVATE); err == nil {
		buffer = &MBuffer{buffer: mmap[0:0]}
	} else {
		panic(err)
	}
	return
}

type MultiBuffer struct {
	max, unread uint64
	buffers     []Buffer
	read, write int
}

func (mb *MultiBuffer) Empty() bool {
	return mb.unread == 0
}

func (mb *MultiBuffer) Full() bool {
	return mb.max != 0 && mb.unread == mb.max
}

func (mb *MultiBuffer) Reset() {
	mb.unread = 0
	mb.read = 0
	mb.write = 0
	for _, b := range mb.buffers {
		b.Reset()
	}
}

func (mb *MultiBuffer) getBuffer(i int) Buffer {
	n := len(mb.buffers)
	if i < n {
		return mb.buffers[i]
	} else if i == n {
		b := NewMBuffer(1 << 28)
		mb.buffers = append(mb.buffers, b)
		return b
	}
	panic("tried to get buffer out of range")
}

func (mb *MultiBuffer) Write(a Item) {
	mb.unread += 1
	for w := mb.write; ; w++ {
		c := mb.getBuffer(w)
		if c.Full() == false {
			mb.write = w
			c.Write(a)
			break
		}
	}
}

func (mb *MultiBuffer) getReadBuffer() (buffer Buffer) {
	for r, n := mb.read, len(mb.buffers); r < n; r++ {
		c := mb.getBuffer(r)
		if c.Empty() == false {
			buffer = c
			mb.read = r
			break
		}
	}
	return
}

func (mb *MultiBuffer) Peek() (item Item) {
	if mb.unread > 0 {
		if c := mb.getReadBuffer(); c != nil {
			item = c.Peek()
		}
	}
	return
}

func (mb *MultiBuffer) Read() (item Item) {
	if mb.unread > 0 {
		mb.unread -= 1
		if c := mb.getReadBuffer(); c != nil {
			item = c.Read()
		}
	}
	return
}

func (mb *MultiBuffer) Close() {
	for _, b := range mb.buffers {
		b.Close()
	}
	mb.buffers = nil
}

func NewBuffer() Buffer {
	return &MultiBuffer{}
}

func NewBufferSize(n uint64) Buffer {
	return &MultiBuffer{max: n}
}

func hyperceil(x float64) uint64 {
	return uint64(math.Exp2(math.Ceil(math.Log2(x))))
}

type Funnel struct {
	height      uint64
	index       int
	exhausted   bool
	out         Buffer
	left, right *Funnel
	top         *Funnel
	bottom      []*Funnel
}

func (f *Funnel) K() uint64 {
	return uint64(math.Exp2(float64(f.height)))
}

func (f *Funnel) root() (root *Funnel) {
	if f.top == nil {
		root = f
	} else {
		root = f.top.root()
	}
	return root
}

func (f *Funnel) attach(funnel *Funnel, i int) {
	if funnel.left == nil && funnel.right == nil {
		funnel.left = f.bottom[2*i].root()
		funnel.right = f.bottom[2*i+1].root()
	} else {
		f.attach(funnel.left, i<<1)
		f.attach(funnel.right, i<<1+1)
	}
}

func (f *Funnel) addIndex(funnel *Funnel, i int) {
	if funnel.left == nil && funnel.right == nil {
		funnel.index = i
	} else {
		f.addIndex(funnel.left, i<<1)
		f.addIndex(funnel.right, i<<1+1)
	}
}

func (f *Funnel) attachInput(in []Buffer, i int) {
	if f.left == nil && f.right == nil {
		f.left = &Funnel{out: in[2*i], exhausted: true}
		f.right = &Funnel{out: in[2*i+1], exhausted: true}
	} else {
		f.left.attachInput(in, i<<1)
		f.right.attachInput(in, i<<1+1)
	}
}

func (f *Funnel) fill(out Writer) {
	bout, ok := out.(Buffer)
	if ok {
		bout.Reset()
	}
	for bout == nil || bout.Full() == false {
		if f.left.exhausted == false && f.left.out.Empty() {
			f.left.fill(f.left.out)
		}
		if f.right.exhausted == false && f.right.out.Empty() {
			f.right.fill(f.right.out)
		}
		if f.left.out.Empty() {
			if f.right.out.Empty() {
				f.left.out.Close()
				f.right.out.Close()
				f.exhausted = true
				break
			} else {
				out.Write(f.right.out.Read())
			}
		} else {
			if f.right.out.Empty() {
				out.Write(f.left.out.Read())
			} else {
				if f.left.out.Peek().Less(f.right.out.Peek()) {
					out.Write(f.left.out.Read())
				} else {
					out.Write(f.right.out.Read())
				}
			}
		}
	}
}

func (f *Funnel) Fill(in []Buffer, out Writer) {
	root := f.root()
	root.attachInput(in, 0)
	root.fill(out)
}

func (f *Funnel) Close() {
	if f.top != nil {
		f.top.Close()
	}
	for _, b := range f.bottom {
		b.Close()
	}
	if f.out != nil {
		f.out.Close()
	}
	if f.left != nil {
		f.left.Close()
	}
	if f.right != nil {
		f.right.Close()
	}
}

func NewFunnelK(k int) *Funnel {
	kk := uint64(hyperceil(float64(k)))
	h := uint64(math.Ceil(math.Log2(float64(kk))))
	return NewFunnel(h)
}

func NewFunnel(height uint64) *Funnel {
	f := &Funnel{height: height}
	if height > 1 {
		heightBottom := hyperceil(float64(height) / 2.)
		heightTop := height - heightBottom
		f.top = NewFunnel(heightTop)
		k := f.top.K()
		f.bottom = make([]*Funnel, k)
		bsize := uint64(math.Ceil(math.Pow(float64(k), 1.5)))
		f.top.out = NewBufferSize(bsize)
		for i, _ := range f.bottom {
			f.bottom[i] = NewFunnel(heightBottom)
			f.bottom[i].out = NewBufferSize(bsize)
		}
		f.attach(f.top.root(), 0)
	}
	f.addIndex(f.root(), 0)
	return f
}

type itemSlice []Item

func (p itemSlice) Len() int           { return len(p) }
func (p itemSlice) Less(i, j int) bool { return p[i].Less(p[j]) }
func (p itemSlice) Swap(i, j int)      { p[i], p[j] = p[j], p[i] }

type itemBuffer struct {
	buf itemSlice
}

func (p *itemBuffer) Close() {
}

func (p *itemBuffer) Empty() bool {
	return len(p.buf) == 0
}

func (p *itemBuffer) Full() bool {
	return false
}

func (p *itemBuffer) Reset() {
	p.buf = p.buf[0:0]
}

func (p *itemBuffer) Write(a Item) {
	p.buf = append(p.buf, a)
}

func (p *itemBuffer) Peek() (item Item) {
	if len(p.buf) > 0 {
		item = p.buf[0]
	}
	return
}

func (p *itemBuffer) Read() (item Item) {
	if len(p.buf) > 0 {
		item = p.buf[0]
		p.buf = p.buf[1:]
	}
	return
}

const p = uint(16)
const kSquared = 1 << p

var itemArray [kSquared]Item

func manual(in Reader) (items itemSlice, done bool) {
	items = itemSlice(itemArray[0:0])
	for i := 0; i < kSquared; i++ {
		if item := in.Read(); item != nil {
			items = append(items, item)
		} else {
			done = true
			break
		}
	}
	sort.Sort(items)
	return
}

var empty = &itemBuffer{make(itemSlice, 0)}

func Merge(buffers []Buffer, out Writer) {
	if len(buffers) == 1 {
		in := buffers[0]
		for {
			item := in.Read();
			if item == nil {
				break
			} else {
				out.Write(item)
			}
		}
	} else if len(buffers) > 0 {
		f := NewFunnelK(len(buffers))

		// pad the remaining inputs with an empty buffer
		for k := int(f.K()); len(buffers) < k; {
			buffers = append(buffers, empty)
		}
		f.Fill(buffers, out)
		f.Close()
		for _, b := range buffers {
			b.Close()
		}
	}
	return
}

func FunnelSort(in Reader, out Writer) {
	items, done := manual(in)
	if done {
		for _, item := range items {
			out.Write(item)
		}
		return
	}

	var buffers []Buffer
	for kMax := 1 << (p / 2); ; {
		for len(buffers) < kMax {
			buffer := NewBuffer()
			for _, item := range items {
				buffer.Write(item)
			}
			buffers = append(buffers, buffer)
			if done {
				break
			} else {
				items, done = manual(in)
			}
		}
		if done {
			Merge(buffers, out)
			break
		} else {
			buffer := NewBuffer()
			Merge(buffers, buffer)
			buffers = buffers[0:0]
			buffers = append(buffers, buffer)
			kMax += (1 << (p / 2))
		}
	}
}
```


