

//DCache
`define INDEX_SIZE_D       7//行索引大小
`define WORD_OFF_SIZE_D    (30-`TAG_SIZE_D-`INDEX_SIZE_D)//字偏移量大小
`define TAG_SIZE_D         19//标签地址大小
`define AXI_SIZE_D         3'b010
`define AXI_COUNT_D        4'b1111
`define CNT_SIZE_D         3

//ICache
`define INDEX_SIZE_I       7//行索引大小
`define WORD_OFF_SIZE_I    (30-`TAG_SIZE_I-`INDEX_SIZE_I)//字偏移量大小
`define TAG_SIZE_I         19//标签地址大小
`define AXI_SIZE_I         3'b010
`define AXI_COUNT_I        4'b1111
`define CNT_SIZE_I         3

//AXI_COUNT = 2**WORD_OFF_SIZE - 1
`define WAY_SIZE_ICACHE  4'b0010
`define WAY_SIZE_DCACHE  4'b0010
//别忘了改IP核