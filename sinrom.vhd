library IEEE;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;

package sincos is
function sinoffset(sinent : unsigned18; lowbits : unsigned2) return unsigned3;
constant sinrom : sinrom_t := (
    "11"&x"c001", "11"&x"c009", "11"&x"c011", "11"&x"c019",
    "11"&x"c021", "11"&x"c029", "11"&x"c031", "11"&x"c039",
    "11"&x"c041", "11"&x"c049", "11"&x"c051", "11"&x"c059",
    "11"&x"c061", "11"&x"c069", "11"&x"c071", "11"&x"c079",
    "11"&x"c081", "11"&x"c089", "11"&x"c091", "11"&x"c099",
    "11"&x"c0a1", "11"&x"c0a9", "11"&x"c0b1", "11"&x"c0b9",
    "11"&x"c0c1", "11"&x"c0c9", "11"&x"c0d1", "11"&x"c0d9",
    "11"&x"c0e1", "11"&x"c0e9", "11"&x"c0f1", "11"&x"c0f9",
    "11"&x"c101", "11"&x"c109", "11"&x"c111", "11"&x"c119",
    "11"&x"c121", "11"&x"c129", "11"&x"c131", "11"&x"c139",
    "11"&x"c141", "11"&x"c149", "11"&x"c151", "11"&x"c159",
    "11"&x"c161", "11"&x"c169", "11"&x"c171", "11"&x"c179",
    "11"&x"c181", "11"&x"c189", "11"&x"c191", "11"&x"c199",
    "11"&x"c1a1", "11"&x"c1a9", "11"&x"81b1", "11"&x"c1b8",
    "11"&x"c1c0", "11"&x"c1c8", "11"&x"c1d0", "11"&x"c1d8",
    "11"&x"c1e0", "11"&x"c1e8", "11"&x"c1f0", "11"&x"c1f8",
    "11"&x"c200", "11"&x"c208", "11"&x"c210", "11"&x"c218",
    "11"&x"c220", "11"&x"c228", "11"&x"c230", "11"&x"c238",
    "11"&x"c240", "11"&x"c248", "11"&x"c250", "11"&x"c258",
    "11"&x"c260", "11"&x"c268", "11"&x"8270", "11"&x"c277",
    "11"&x"c27f", "11"&x"c287", "11"&x"c28f", "11"&x"c297",
    "11"&x"c29f", "11"&x"c2a7", "11"&x"c2af", "11"&x"c2b7",
    "11"&x"c2bf", "11"&x"c2c7", "11"&x"c2cf", "11"&x"c2d7",
    "10"&x"c2df", "11"&x"c2e6", "11"&x"c2ee", "11"&x"c2f6",
    "11"&x"c2fe", "11"&x"c306", "11"&x"c30e", "11"&x"c316",
    "11"&x"c31e", "11"&x"c326", "11"&x"c32e", "10"&x"c336",
    "11"&x"c33d", "11"&x"c345", "11"&x"c34d", "11"&x"c355",
    "11"&x"c35d", "11"&x"c365", "11"&x"c36d", "11"&x"c375",
    "10"&x"c37d", "11"&x"c384", "11"&x"c38c", "11"&x"c394",
    "11"&x"c39c", "11"&x"c3a4", "11"&x"c3ac", "11"&x"c3b4",
    "10"&x"c3bc", "11"&x"c3c3", "11"&x"c3cb", "11"&x"c3d3",
    "11"&x"c3db", "11"&x"c3e3", "11"&x"c3eb", "11"&x"43f3",
    "11"&x"c3fa", "11"&x"c402", "11"&x"c40a", "11"&x"c412",
    "11"&x"c41a", "10"&x"c422", "11"&x"c429", "11"&x"c431",
    "11"&x"c439", "11"&x"c441", "11"&x"c449", "11"&x"4451",
    "11"&x"c458", "11"&x"c460", "11"&x"c468", "11"&x"c470",
    "10"&x"c478", "11"&x"c47f", "11"&x"c487", "11"&x"c48f",
    "11"&x"c497", "10"&x"c49f", "11"&x"c4a6", "11"&x"c4ae",
    "11"&x"c4b6", "11"&x"c4be", "11"&x"84c6", "11"&x"c4cd",
    "11"&x"c4d5", "11"&x"c4dd", "10"&x"c4e5", "11"&x"c4ec",
    "11"&x"c4f4", "11"&x"c4fc", "10"&x"c504", "11"&x"c50b",
    "11"&x"c513", "11"&x"c51b", "10"&x"c523", "11"&x"c52a",
    "11"&x"c532", "11"&x"c53a", "11"&x"4542", "11"&x"c549",
    "11"&x"c551", "11"&x"c559", "11"&x"c560", "11"&x"c568",
    "11"&x"c570", "11"&x"4578", "11"&x"c57f", "11"&x"c587",
    "11"&x"c58f", "11"&x"c596", "11"&x"c59e", "11"&x"c5a6",
    "11"&x"c5ad", "11"&x"c5b5", "11"&x"c5bd", "11"&x"85c5",
    "11"&x"c5cc", "11"&x"c5d4", "11"&x"85dc", "11"&x"c5e3",
    "11"&x"c5eb", "11"&x"c5f2", "11"&x"c5fa", "11"&x"c602",
    "11"&x"c609", "11"&x"c611", "10"&x"c619", "11"&x"c620",
    "11"&x"c628", "11"&x"4630", "11"&x"c637", "11"&x"c63f",
    "11"&x"c646", "11"&x"c64e", "11"&x"4656", "11"&x"c65d",
    "11"&x"c665", "11"&x"c66c", "11"&x"c674", "11"&x"467c",
    "11"&x"c683", "10"&x"c68b", "11"&x"c692", "11"&x"c69a",
    "11"&x"86a2", "11"&x"c6a9", "11"&x"46b1", "11"&x"c6b8",
    "11"&x"46c0", "11"&x"c6c7", "10"&x"c6cf", "11"&x"c6d6",
    "11"&x"c6de", "11"&x"c6e5", "11"&x"c6ed", "11"&x"c6f4",
    "11"&x"c6fc", "11"&x"c703", "11"&x"c70b", "11"&x"8713",
    "11"&x"c71a", "11"&x"8722", "11"&x"c729", "11"&x"c730",
    "11"&x"c738", "11"&x"c73f", "11"&x"c747", "11"&x"c74e",
    "10"&x"c756", "11"&x"c75d", "11"&x"4765", "11"&x"c76c",
    "11"&x"4774", "11"&x"c77b", "11"&x"8783", "11"&x"c78a",
    "11"&x"c791", "10"&x"c799", "11"&x"c7a0", "11"&x"47a8",
    "11"&x"c7af", "11"&x"c7b6", "10"&x"c7be", "11"&x"c7c5",
    "11"&x"47cd", "11"&x"c7d4", "11"&x"c7db", "10"&x"c7e3",
    "11"&x"c7ea", "11"&x"87f2", "10"&x"c7f9", "11"&x"c800",
    "11"&x"4808", "11"&x"c80f", "11"&x"c816", "11"&x"481e",
    "11"&x"c825", "11"&x"c82c", "11"&x"4834", "10"&x"c83b",
    "11"&x"c842", "11"&x"884a", "10"&x"c851", "11"&x"c858",
    "11"&x"8860", "11"&x"4867", "11"&x"c86e", "11"&x"c875",
    "11"&x"887d", "10"&x"c884", "11"&x"c88b", "11"&x"c892",
    "11"&x"489a", "10"&x"c8a1", "11"&x"c8a8", "11"&x"c8af",
    "11"&x"88b7", "10"&x"c8be", "11"&x"c8c5", "11"&x"c8cc",
    "11"&x"88d4", "11"&x"48db", "10"&x"c8e2", "11"&x"c8e9",
    "11"&x"c8f0", "11"&x"88f8", "11"&x"48ff", "11"&x"4906",
    "10"&x"c90d", "11"&x"c914", "11"&x"c91b", "11"&x"8923",
    "11"&x"892a", "11"&x"4931", "10"&x"c938", "10"&x"c93f",
    "11"&x"c946", "11"&x"c94d", "11"&x"c954", "11"&x"895c",
    "11"&x"8963", "11"&x"496a", "11"&x"4971", "10"&x"c978",
    "10"&x"c97f", "10"&x"c986", "10"&x"c98d", "11"&x"c994",
    "11"&x"c99b", "11"&x"c9a2", "11"&x"c9a9", "11"&x"c9b0",
    "11"&x"c9b7", "11"&x"89bf", "11"&x"89c6", "11"&x"89cd",
    "11"&x"89d4", "11"&x"89db", "11"&x"89e2", "11"&x"89e9",
    "11"&x"89f0", "11"&x"89f7", "11"&x"c9fd", "11"&x"ca04",
    "11"&x"ca0b", "11"&x"ca12", "11"&x"ca19", "10"&x"ca20",
    "10"&x"ca27", "10"&x"ca2e", "10"&x"ca35", "11"&x"4a3c",
    "11"&x"4a43", "11"&x"4a4a", "11"&x"8a51", "11"&x"8a58",
    "11"&x"8a5f", "11"&x"ca65", "10"&x"ca6c", "10"&x"ca73",
    "11"&x"4a7a", "11"&x"4a81", "11"&x"8a88", "11"&x"8a8f",
    "11"&x"ca95", "10"&x"ca9c", "11"&x"4aa3", "11"&x"4aaa",
    "11"&x"8ab1", "11"&x"cab7", "10"&x"cabe", "11"&x"4ac5",
    "11"&x"4acc", "11"&x"8ad3", "11"&x"cad9", "10"&x"cae0",
    "11"&x"4ae7", "11"&x"8aee", "11"&x"caf4", "10"&x"cafb",
    "11"&x"4b02", "11"&x"8b09", "10"&x"cb0f", "11"&x"4b16",
    "11"&x"8b1d", "11"&x"8b24", "10"&x"cb2a", "11"&x"4b31",
    "11"&x"8b38", "10"&x"cb3e", "11"&x"4b45", "11"&x"8b4c",
    "10"&x"cb52", "11"&x"4b59", "10"&x"8b60", "11"&x"4b66",
    "11"&x"8b6d", "10"&x"cb73", "11"&x"4b7a", "11"&x"8b81",
    "10"&x"cb87", "11"&x"8b8e", "10"&x"cb94", "11"&x"4b9b",
    "10"&x"8ba2", "11"&x"4ba8", "11"&x"8baf", "11"&x"4bb5",
    "11"&x"8bbc", "10"&x"cbc2", "11"&x"8bc9", "10"&x"cbcf",
    "11"&x"8bd6", "10"&x"cbdc", "11"&x"4be3", "10"&x"cbe9",
    "11"&x"8bf0", "10"&x"cbf6", "11"&x"8bfd", "10"&x"cc03",
    "11"&x"8c0a", "11"&x"4c10", "10"&x"8c17", "11"&x"4c1d",
    "10"&x"cc23", "11"&x"4c2a", "10"&x"cc30", "11"&x"8c37",
    "11"&x"4c3d", "10"&x"8c44", "11"&x"8c4a", "11"&x"4c50",
    "10"&x"8c57", "11"&x"4c5d", "10"&x"cc63", "10"&x"8c6a",
    "11"&x"4c70", "10"&x"cc76", "10"&x"8c7d", "11"&x"4c83",
    "11"&x"4c89", "10"&x"8c90", "11"&x"4c96", "11"&x"4c9c",
    "10"&x"8ca3", "10"&x"8ca9", "11"&x"4caf", "11"&x"4cb5",
    "10"&x"8cbc", "10"&x"8cc2", "11"&x"4cc8", "11"&x"4cce",
    "10"&x"ccd4", "10"&x"8cdb", "11"&x"8ce1", "11"&x"4ce7",
    "11"&x"4ced", "10"&x"ccf3", "10"&x"8cfa", "10"&x"8d00",
    "11"&x"8d06", "11"&x"4d0c", "11"&x"4d12", "11"&x"4d18",
    "10"&x"cd1e", "10"&x"8d25", "10"&x"8d2b", "10"&x"8d31",
    "10"&x"8d37", "11"&x"8d3d", "11"&x"4d43", "11"&x"4d49",
    "11"&x"4d4f", "11"&x"4d55", "11"&x"4d5b", "11"&x"4d61",
    "11"&x"4d67", "11"&x"4d6d", "11"&x"4d73", "11"&x"4d79",
    "11"&x"4d7f", "11"&x"4d85", "11"&x"4d8b", "11"&x"4d91",
    "11"&x"4d97", "11"&x"4d9d", "11"&x"4da3", "11"&x"4da9",
    "10"&x"4daf", "10"&x"8db5", "10"&x"8dbb", "10"&x"8dc1",
    "10"&x"8dc7", "10"&x"8dcd", "11"&x"4dd2", "11"&x"4dd8",
    "11"&x"4dde", "10"&x"4de4", "10"&x"8dea", "10"&x"8df0",
    "11"&x"0df6", "11"&x"4dfb", "11"&x"4e01", "10"&x"8e07",
    "10"&x"8e0d", "11"&x"0e13", "11"&x"4e18", "10"&x"4e1e",
    "10"&x"8e24", "10"&x"8e2a", "11"&x"4e2f", "10"&x"4e35",
    "10"&x"8e3b", "11"&x"0e41", "11"&x"4e46", "10"&x"8e4c",
    "10"&x"8e52", "11"&x"4e57", "10"&x"8e5d", "10"&x"8e63",
    "11"&x"4e68", "10"&x"8e6e", "10"&x"8e74", "11"&x"4e79",
    "10"&x"8e7f", "11"&x"0e85", "10"&x"4e8a", "10"&x"8e90",
    "11"&x"4e95", "10"&x"8e9b", "11"&x"0ea1", "10"&x"8ea6",
    "11"&x"0eac", "10"&x"4eb1", "11"&x"0eb7", "10"&x"4ebc",
    "10"&x"8ec2", "10"&x"4ec7", "10"&x"8ecd", "10"&x"4ed2",
    "10"&x"8ed8", "10"&x"4edd", "11"&x"0ee3", "10"&x"4ee8",
    "11"&x"0eee", "10"&x"8ef3", "11"&x"4ef8", "10"&x"8efe",
    "10"&x"4f03", "11"&x"0f09", "10"&x"8f0e", "11"&x"4f13",
    "10"&x"8f19", "10"&x"4f1e", "11"&x"0f24", "10"&x"8f29",
    "10"&x"4f2e", "11"&x"0f34", "10"&x"8f39", "10"&x"4f3e",
    "11"&x"0f44", "11"&x"0f49", "10"&x"8f4e", "10"&x"4f53",
    "11"&x"0f59", "10"&x"8f5e", "10"&x"8f63", "10"&x"4f68",
    "11"&x"0f6e", "11"&x"0f73", "10"&x"8f78", "10"&x"4f7d",
    "10"&x"4f82", "11"&x"0f88", "11"&x"0f8d", "10"&x"8f92",
    "10"&x"8f97", "10"&x"4f9c", "10"&x"4fa1", "10"&x"0fa7",
    "10"&x"0fac", "11"&x"0fb1", "11"&x"0fb6", "11"&x"0fbb",
    "10"&x"8fc0", "10"&x"8fc5", "10"&x"8fca", "10"&x"8fcf",
    "10"&x"4fd4", "10"&x"4fd9", "10"&x"4fde", "10"&x"4fe3",
    "10"&x"4fe8", "10"&x"4fed", "10"&x"4ff2", "10"&x"4ff7",
    "10"&x"8ffc", "10"&x"9001", "10"&x"9006", "10"&x"900b",
    "11"&x"1010", "11"&x"1015", "10"&x"101a", "10"&x"101f",
    "10"&x"1024", "10"&x"5028", "10"&x"502d", "10"&x"9032",
    "11"&x"1037", "11"&x"103c", "10"&x"1041", "10"&x"1046",
    "10"&x"504a", "10"&x"904f", "11"&x"1054", "10"&x"1059",
    "10"&x"505d", "10"&x"9062", "11"&x"1067", "10"&x"106c",
    "10"&x"5070", "10"&x"9075", "10"&x"107a", "10"&x"107f",
    "10"&x"9083", "10"&x"1088", "10"&x"108d", "10"&x"9091",
    "10"&x"1096", "10"&x"109b", "10"&x"909f", "10"&x"10a4",
    "10"&x"50a8", "10"&x"10ad", "10"&x"10b2", "11"&x"10b6",
    "10"&x"10bb", "10"&x"90bf", "10"&x"10c4", "10"&x"50c8",
    "10"&x"10cd", "10"&x"50d1", "10"&x"10d6", "10"&x"50da",
    "10"&x"10df", "10"&x"50e3", "10"&x"10e8", "10"&x"90ec",
    "10"&x"10f1", "11"&x"10f5", "10"&x"10fa", "10"&x"10fe",
    "10"&x"1103", "10"&x"1107", "11"&x"110b", "10"&x"1110",
    "10"&x"1114", "10"&x"9118", "10"&x"111d", "10"&x"1121",
    "10"&x"9125", "10"&x"112a", "10"&x"112e", "11"&x"1132",
    "10"&x"1137", "10"&x"113b", "10"&x"113f", "10"&x"9143",
    "10"&x"1148", "10"&x"114c", "10"&x"1150", "10"&x"1154",
    "10"&x"1159", "10"&x"115d", "10"&x"1161", "10"&x"1165",
    "10"&x"1169", "10"&x"116d", "10"&x"5171", "10"&x"1176",
    "10"&x"117a", "10"&x"117e", "10"&x"1182", "10"&x"1186",
    "10"&x"118a", "10"&x"118e", "10"&x"1192", "10"&x"1196",
    "10"&x"119a", "10"&x"119e", "10"&x"11a2", "10"&x"11a6",
    "10"&x"11aa", "10"&x"11ae", "10"&x"11b2", "10"&x"11b6",
    "10"&x"11ba", "10"&x"11be", "10"&x"11c2", "10"&x"11c6",
    "10"&x"11ca", "10"&x"11ce", "10"&x"11d2", "10"&x"11d5",
    "10"&x"11d9", "10"&x"11dd", "10"&x"11e1", "10"&x"11e5",
    "10"&x"11e9", "10"&x"11ec", "10"&x"11f0", "10"&x"11f4",
    "10"&x"11f8", "00"&x"d1fc", "10"&x"11ff", "10"&x"1203",
    "10"&x"1207", "01"&x"d20b", "10"&x"120e", "10"&x"1212",
    "00"&x"d216", "10"&x"1219", "10"&x"121d", "01"&x"9221",
    "10"&x"1224", "10"&x"1228", "01"&x"d22c", "10"&x"122f",
    "00"&x"d233", "10"&x"1236", "10"&x"123a", "01"&x"d23e",
    "10"&x"1241", "01"&x"9245", "10"&x"1248", "01"&x"924c",
    "10"&x"124f", "01"&x"9253", "10"&x"1256", "01"&x"925a",
    "10"&x"125d", "01"&x"d261", "10"&x"1264", "10"&x"1267",
    "00"&x"d26b", "10"&x"126e", "01"&x"9272", "10"&x"1275",
    "10"&x"1278", "00"&x"d27c", "10"&x"127f", "01"&x"d283",
    "00"&x"d286", "10"&x"1289", "01"&x"d28d", "01"&x"9290",
    "10"&x"1293", "10"&x"1296", "01"&x"d29a", "00"&x"d29d",
    "10"&x"12a0", "10"&x"12a3", "01"&x"d2a7", "01"&x"92aa",
    "00"&x"d2ad", "10"&x"12b0", "10"&x"12b3", "01"&x"d2b7",
    "01"&x"92ba", "01"&x"92bd", "00"&x"d2c0", "00"&x"d2c3",
    "10"&x"12c6", "10"&x"12c9", "10"&x"12cc", "01"&x"d2d0",
    "01"&x"d2d3", "01"&x"d2d6", "01"&x"d2d9", "01"&x"d2dc",
    "01"&x"d2df", "01"&x"d2e2", "01"&x"d2e5", "01"&x"d2e8",
    "01"&x"d2eb", "01"&x"d2ee", "01"&x"d2f1", "01"&x"d2f4",
    "10"&x"12f6", "10"&x"12f9", "00"&x"d2fc", "00"&x"d2ff",
    "00"&x"d302", "01"&x"9305", "01"&x"9308", "01"&x"d30b",
    "01"&x"d30e", "00"&x"d310", "00"&x"d313", "01"&x"9316",
    "01"&x"d319", "01"&x"d31c", "00"&x"d31e", "01"&x"9321",
    "01"&x"d324", "01"&x"d327", "00"&x"d329", "01"&x"932c",
    "01"&x"d32f", "00"&x"d331", "01"&x"9334", "01"&x"d337",
    "00"&x"d339", "01"&x"933c", "01"&x"d33f", "00"&x"d341",
    "01"&x"d344", "00"&x"d346", "01"&x"9349", "01"&x"d34c",
    "01"&x"934e", "01"&x"d351", "00"&x"d353", "01"&x"d356",
    "00"&x"d358", "01"&x"d35b", "00"&x"d35d", "01"&x"d360",
    "01"&x"9362", "01"&x"d365", "01"&x"9367", "00"&x"936a",
    "01"&x"936c", "00"&x"d36e", "01"&x"d371", "01"&x"9373",
    "00"&x"9376", "01"&x"d378", "01"&x"937a", "00"&x"937d",
    "01"&x"d37f", "01"&x"9381", "00"&x"9384", "01"&x"d386",
    "01"&x"9388", "00"&x"d38a", "00"&x"938d", "01"&x"d38f",
    "01"&x"9391", "01"&x"9393", "00"&x"9396", "00"&x"9398",
    "01"&x"d39a", "01"&x"939c", "01"&x"939e", "01"&x"93a0",
    "00"&x"93a3", "00"&x"93a5", "00"&x"93a7", "00"&x"93a9",
    "01"&x"d3ab", "01"&x"93ad", "01"&x"93af", "01"&x"93b1",
    "01"&x"93b3", "01"&x"93b5", "01"&x"93b7", "01"&x"93b9",
    "01"&x"93bb", "01"&x"93bd", "01"&x"93bf", "01"&x"93c1",
    "01"&x"93c3", "01"&x"93c5", "00"&x"93c7", "00"&x"93c9",
    "00"&x"93cb", "00"&x"93cd", "00"&x"93cf", "01"&x"93d0",
    "01"&x"93d2", "01"&x"93d4", "00"&x"93d6", "00"&x"93d8",
    "01"&x"53da", "01"&x"93db", "00"&x"53dd", "00"&x"93df",
    "00"&x"93e1", "01"&x"93e2", "00"&x"53e4", "00"&x"93e6",
    "01"&x"53e8", "01"&x"93e9", "00"&x"93eb", "01"&x"53ed",
    "01"&x"93ee", "00"&x"93f0", "01"&x"53f2", "00"&x"53f3",
    "00"&x"93f5", "01"&x"93f6", "00"&x"93f8", "01"&x"53fa",
    "00"&x"53fb", "00"&x"93fd", "00"&x"53fe", "00"&x"9400",
    "00"&x"5401", "00"&x"9403", "00"&x"5404", "00"&x"9406",
    "00"&x"5407", "01"&x"5409", "00"&x"540a", "01"&x"540c",
    "00"&x"940d", "00"&x"540e", "00"&x"9410", "00"&x"5411",
    "01"&x"5413", "00"&x"9414", "00"&x"5415", "01"&x"5417",
    "00"&x"9418", "00"&x"5419", "01"&x"541b", "01"&x"541c",
    "00"&x"941d", "00"&x"541e", "01"&x"5420", "01"&x"5421",
    "00"&x"9422", "00"&x"5423", "00"&x"1425", "01"&x"5426",
    "01"&x"5427", "00"&x"9428", "00"&x"9429", "00"&x"542a",
    "00"&x"542b", "00"&x"142d", "01"&x"542e", "01"&x"542f",
    "01"&x"5430", "01"&x"5431", "00"&x"9432", "00"&x"9433",
    "00"&x"9434", "00"&x"9435", "00"&x"9436", "00"&x"9437",
    "00"&x"9438", "00"&x"9439", "01"&x"543a", "01"&x"543b",
    "01"&x"543c", "01"&x"543d", "00"&x"143e", "00"&x"143f",
    "00"&x"1440", "00"&x"5440", "00"&x"9441", "00"&x"9442",
    "01"&x"5443", "00"&x"1444", "00"&x"1445", "00"&x"5445",
    "00"&x"9446", "01"&x"5447", "00"&x"1448", "00"&x"5448",
    "00"&x"9449", "00"&x"144a", "00"&x"144b", "00"&x"544b",
    "01"&x"544c", "00"&x"144d", "00"&x"544d", "01"&x"544e",
    "00"&x"144f", "00"&x"944f", "00"&x"1450", "00"&x"1451",
    "01"&x"5451", "00"&x"1452", "00"&x"9452", "00"&x"1453",
    "00"&x"5453", "00"&x"1454", "00"&x"5454", "00"&x"1455",
    "00"&x"5455", "00"&x"1456", "00"&x"5456", "00"&x"1457",
    "00"&x"9457", "00"&x"1458", "00"&x"1458", "00"&x"1459",
    "00"&x"1459", "00"&x"9459", "00"&x"145a", "00"&x"145a",
    "00"&x"545a", "00"&x"145b", "00"&x"145b", "00"&x"945b",
    "00"&x"145c", "00"&x"145c", "00"&x"145c", "00"&x"145d",
    "00"&x"145d", "00"&x"145d", "00"&x"145d", "00"&x"945d",
    "00"&x"145e", "00"&x"145e", "00"&x"145e", "00"&x"145e",
    "00"&x"145e", "00"&x"945e", "00"&x"145f", "00"&x"145f",
    "00"&x"145f", "00"&x"145f", "00"&x"145f", "00"&x"145f",
    "00"&x"145f", "00"&x"145f", "00"&x"145f", "00"&x"145f");
    -- Used bitmask: ffef
end sincos;

package body sincos is
function sinoffset(sinent : unsigned18; lowbits : unsigned2) return unsigned3 is
begin
    case lowbits & sinent(17 downto 14) is
    when "00" & x"1" => return "000"; -- 001 1110
    when "00" & x"2" => return "000"; -- 010 1100
    when "00" & x"3" => return "000"; -- 011 2210
    when "00" & x"4" => return "000"; -- 012 3320
    when "00" & x"5" => return "000"; -- 100 1000
    when "00" & x"6" => return "000"; -- 101 2110
    when "00" & x"7" => return "000"; -- 110 2100
    when "00" & x"8" => return "000"; -- 111 3210
    when "00" & x"9" => return "000"; -- 112 4320
    when "00" & x"a" => return "000"; -- 121 4310
    when "00" & x"b" => return "000"; -- 122 5420
    when "00" & x"c" => return "000"; -- 211 4210
    when "00" & x"d" => return "000"; -- 212 5320
    when "00" & x"e" => return "000"; -- 221 5310
    when "00" & x"f" => return "000"; -- 222 6420
    when "01" & x"0" => return "000"; -- 000 0000
    when "01" & x"1" => return "001"; -- 001 1110
    when "01" & x"2" => return "000"; -- 010 1100
    when "01" & x"3" => return "001"; -- 011 2210
    when "01" & x"4" => return "010"; -- 012 3320
    when "01" & x"5" => return "000"; -- 100 1000
    when "01" & x"6" => return "001"; -- 101 2110
    when "01" & x"7" => return "000"; -- 110 2100
    when "01" & x"8" => return "001"; -- 111 3210
    when "01" & x"9" => return "010"; -- 112 4320
    when "01" & x"a" => return "001"; -- 121 4310
    when "01" & x"b" => return "010"; -- 122 5420
    when "01" & x"c" => return "001"; -- 211 4210
    when "01" & x"d" => return "010"; -- 212 5320
    when "01" & x"e" => return "001"; -- 221 5310
    when "01" & x"f" => return "010"; -- 222 6420
    when "10" & x"0" => return "000"; -- 000 0000
    when "10" & x"1" => return "001"; -- 001 1110
    when "10" & x"2" => return "001"; -- 010 1100
    when "10" & x"3" => return "010"; -- 011 2210
    when "10" & x"4" => return "011"; -- 012 3320
    when "10" & x"5" => return "000"; -- 100 1000
    when "10" & x"6" => return "001"; -- 101 2110
    when "10" & x"7" => return "001"; -- 110 2100
    when "10" & x"8" => return "010"; -- 111 3210
    when "10" & x"9" => return "011"; -- 112 4320
    when "10" & x"a" => return "011"; -- 121 4310
    when "10" & x"b" => return "100"; -- 122 5420
    when "10" & x"c" => return "010"; -- 211 4210
    when "10" & x"d" => return "011"; -- 212 5320
    when "10" & x"e" => return "011"; -- 221 5310
    when "10" & x"f" => return "100"; -- 222 6420
    when "11" & x"0" => return "000"; -- 000 0000
    when "11" & x"1" => return "001"; -- 001 1110
    when "11" & x"2" => return "001"; -- 010 1100
    when "11" & x"3" => return "010"; -- 011 2210
    when "11" & x"4" => return "011"; -- 012 3320
    when "11" & x"5" => return "001"; -- 100 1000
    when "11" & x"6" => return "010"; -- 101 2110
    when "11" & x"7" => return "010"; -- 110 2100
    when "11" & x"8" => return "011"; -- 111 3210
    when "11" & x"9" => return "100"; -- 112 4320
    when "11" & x"a" => return "100"; -- 121 4310
    when "11" & x"b" => return "101"; -- 122 5420
    when "11" & x"c" => return "100"; -- 211 4210
    when "11" & x"d" => return "101"; -- 212 5320
    when "11" & x"e" => return "101"; -- 221 5310
    when "11" & x"f" => return "110"; -- 222 6420
    when others => return "000";
    end case;
end sinoffset;
end sincos;
