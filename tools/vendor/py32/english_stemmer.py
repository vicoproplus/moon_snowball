# Generated from english.sbl by Snowball 3.2.0 - https://snowballstem.org/

from .basestemmer import BaseStemmer
from .among import Among


class EnglishStemmer(BaseStemmer):
    '''
    This class implements the stemming algorithm defined by a snowball script.
    Generated from english.sbl by Snowball 3.2.0 - https://snowballstem.org/
    '''

    g_aeo = "aeo"
    g_v = {"a", "e", "i", "o", "u", "y"}

    g_v_WXY = {"Y", "a", "e", "i", "o", "u", "w", "x", "y"}

    g_valid_LI = {"c", "d", "e", "g", "h", "k", "m", "n", "r", "t"}


    def __r_shortv(self):
        while True:
            v_1 = self.limit - self.cursor
            try:
                if not self.out_grouping_b(EnglishStemmer.g_v_WXY):
                    raise lab0()
                if not self.in_grouping_b(EnglishStemmer.g_v):
                    raise lab0()
                if not self.out_grouping_b(EnglishStemmer.g_v):
                    raise lab0()
                break
            except lab0: pass
            self.cursor = self.limit - v_1
            try:
                if not self.out_grouping_b(EnglishStemmer.g_v):
                    raise lab0()
                if not self.in_grouping_b(EnglishStemmer.g_v):
                    raise lab0()
                if self.cursor > self.limit_backward:
                    raise lab0()
                break
            except lab0: pass
            self.cursor = self.limit - v_1
            if not self.eq_s_b("past"):
                return False
            break
        return True

    def _stem(self):
        while True:
            v_1 = self.cursor
            try:
                self.bra = self.cursor
                among_var = self.find_among(EnglishStemmer.a_11)
                if among_var == 0:
                    raise lab0()
                self.ket = self.cursor
                if self.cursor < self.limit:
                    raise lab0()
                if among_var > 0:
                    self.slice_from(EnglishStemmer.as_11[among_var - 1])
                break
            except lab0: pass
            self.cursor = v_1
            try:
                try:
                    if self.cursor + 3 > self.limit:
                        raise lab1()
                    self.cursor += 3
                    raise lab0()
                except lab1: pass
                break
            except lab0: pass
            self.cursor = v_1
            try:
                B_Y_found = False
                v_2 = self.cursor
                try:
                    self.bra = self.cursor
                    if self.cursor == self.limit or self.current[self.cursor] != "'":
                        raise lab1()
                    self.cursor += 1
                    self.ket = self.cursor
                    self.slice_del()
                except lab1: pass
                self.cursor = v_2
                v_3 = self.cursor
                try:
                    self.bra = self.cursor
                    if self.cursor == self.limit or self.current[self.cursor] != "y":
                        raise lab1()
                    self.cursor += 1
                    self.ket = self.cursor
                    self.slice_from("Y")
                    B_Y_found = True
                except lab1: pass
                self.cursor = v_3
                v_4 = self.cursor
                try:
                    while True:
                        v_5 = self.cursor
                        try:
                            while True:
                                v_6 = self.cursor
                                try:
                                    if not self.in_grouping(EnglishStemmer.g_v):
                                        raise lab3()
                                    self.bra = self.cursor
                                    if self.cursor == self.limit or self.current[self.cursor] != "y":
                                        raise lab3()
                                    self.cursor += 1
                                    self.ket = self.cursor
                                    self.cursor = v_6
                                    break
                                except lab3: pass
                                self.cursor = v_6
                                if self.cursor >= self.limit:
                                    raise lab2()
                                self.cursor += 1
                            self.slice_from("Y")
                            B_Y_found = True
                            continue
                        except lab2: pass
                        self.cursor = v_5
                        break
                except lab1: pass
                self.cursor = v_4
            except lab0: pass
            try:
                I_p1 = self.limit
                I_p2 = self.limit
                v_7 = self.cursor
                try:
                    while True:
                        v_8 = self.cursor
                        try:
                            if self.find_among(EnglishStemmer.a_0) == 0:
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = v_8
                        if not self.go_out_grouping(EnglishStemmer.g_v):
                            raise lab1()
                        self.cursor += 1
                        if not self.go_in_grouping(EnglishStemmer.g_v):
                            raise lab1()
                        self.cursor += 1
                        break
                    I_p1 = self.cursor
                    if not self.go_out_grouping(EnglishStemmer.g_v):
                        raise lab1()
                    self.cursor += 1
                    if not self.go_in_grouping(EnglishStemmer.g_v):
                        raise lab1()
                    self.cursor += 1
                    I_p2 = self.cursor
                except lab1: pass
                self.cursor = v_7
            except lab0: pass
            self.limit_backward = self.cursor
            self.cursor = self.limit
            v_9 = self.limit - self.cursor
            try:
                v_10 = self.limit - self.cursor
                try:
                    self.ket = self.cursor
                    if self.find_among_b(EnglishStemmer.a_1) == 0:
                        self.cursor = self.limit - v_10
                        raise lab1()
                    self.bra = self.cursor
                    self.slice_del()
                except lab1: pass
                self.ket = self.cursor
                among_var = self.find_among_b(EnglishStemmer.a_2)
                if among_var == 0:
                    raise lab0()
                self.bra = self.cursor
                if among_var == 1:
                    self.slice_from("ss")
                elif among_var == 2:
                    while True:
                        v_11 = self.limit - self.cursor
                        try:
                            if self.cursor - 2 < self.limit_backward:
                                raise lab1()
                            self.cursor -= 2
                            self.slice_from("i")
                            break
                        except lab1: pass
                        self.cursor = self.limit - v_11
                        self.slice_from("ie")
                        break
                elif among_var == 3:
                    if self.cursor <= self.limit_backward:
                        raise lab0()
                    self.cursor -= 1
                    if not self.go_out_grouping_b(EnglishStemmer.g_v):
                        raise lab0()
                    self.cursor -= 1
                    self.slice_del()
            except lab0: pass
            self.cursor = self.limit - v_9
            v_12 = self.limit - self.cursor
            try:
                self.ket = self.cursor
                among_var = self.find_among_b(EnglishStemmer.a_5)
                self.bra = self.cursor
                while True:
                    v_13 = self.limit - self.cursor
                    try:
                        if among_var == 1:
                            v_14 = self.limit - self.cursor
                            try:
                                if I_p1 > self.cursor:
                                    raise lab2()
                                while True:
                                    v_15 = self.limit - self.cursor
                                    try:
                                        if self.find_among_b(EnglishStemmer.a_3) == 0:
                                            raise lab3()
                                        if self.cursor > self.limit_backward:
                                            raise lab3()
                                        break
                                    except lab3: pass
                                    self.cursor = self.limit - v_15
                                    self.slice_from("ee")
                                    break
                            except lab2: pass
                            self.cursor = self.limit - v_14
                        elif among_var == 2:
                            raise lab1()
                        elif among_var == 3:
                            among_var = self.find_among_b(EnglishStemmer.a_4)
                            if among_var == 0:
                                raise lab1()
                            if among_var == 1:
                                v_16 = self.limit - self.cursor
                                if not self.out_grouping_b(EnglishStemmer.g_v):
                                    raise lab1()
                                if self.cursor > self.limit_backward:
                                    raise lab1()
                                self.cursor = self.limit - v_16
                                self.bra = self.cursor
                                self.slice_from("ie")
                            else:
                                if self.cursor > self.limit_backward:
                                    raise lab1()
                        break
                    except lab1: pass
                    self.cursor = self.limit - v_13
                    v_17 = self.limit - self.cursor
                    if not self.go_out_grouping_b(EnglishStemmer.g_v):
                        raise lab0()
                    self.cursor -= 1
                    self.cursor = self.limit - v_17
                    self.slice_del()
                    self.ket = self.cursor
                    self.bra = self.cursor
                    v_18 = self.limit - self.cursor
                    among_var = self.find_among_b(EnglishStemmer.a_6)
                    if among_var == 1:
                        self.slice_from("e")
                        raise lab0()
                    elif among_var == 2:
                        v_19 = self.limit - self.cursor
                        try:
                            if not self.in_grouping_b(EnglishStemmer.g_aeo):
                                raise lab1()
                            if self.cursor > self.limit_backward:
                                raise lab1()
                            raise lab0()
                        except lab1: pass
                        self.cursor = self.limit - v_19
                    else:
                        if self.cursor != I_p1:
                            raise lab0()
                        v_20 = self.limit - self.cursor
                        if not self.__r_shortv():
                            raise lab0()
                        self.cursor = self.limit - v_20
                        self.slice_from("e")
                        raise lab0()
                    self.cursor = self.limit - v_18
                    self.ket = self.cursor
                    if self.cursor <= self.limit_backward:
                        raise lab0()
                    self.cursor -= 1
                    self.bra = self.cursor
                    self.slice_del()
                    break
            except lab0: pass
            self.cursor = self.limit - v_12
            v_21 = self.limit - self.cursor
            try:
                self.ket = self.cursor
                while True:
                    try:
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "y":
                            raise lab1()
                        self.cursor -= 1
                        break
                    except lab1: pass
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "Y":
                        raise lab0()
                    self.cursor -= 1
                    break
                self.bra = self.cursor
                if not self.out_grouping_b(EnglishStemmer.g_v):
                    raise lab0()
                if self.cursor <= self.limit_backward:
                    raise lab0()
                self.slice_from("i")
            except lab0: pass
            self.cursor = self.limit - v_21
            v_22 = self.limit - self.cursor
            try:
                self.ket = self.cursor
                among_var = self.find_among_b(EnglishStemmer.a_7)
                if among_var == 0:
                    raise lab0()
                self.bra = self.cursor
                if I_p1 > self.cursor:
                    raise lab0()
                if among_var == 1:
                    self.slice_from("tion")
                elif among_var == 2:
                    self.slice_from("ence")
                elif among_var == 3:
                    self.slice_from("ance")
                elif among_var == 4:
                    self.slice_from("able")
                elif among_var == 5:
                    self.slice_from("ent")
                elif among_var == 6:
                    self.slice_from("ize")
                elif among_var == 7:
                    self.slice_from("ate")
                elif among_var == 8:
                    self.slice_from("al")
                elif among_var == 9:
                    self.slice_from("ful")
                elif among_var == 10:
                    self.slice_from("ous")
                elif among_var == 11:
                    self.slice_from("ive")
                elif among_var == 12:
                    self.slice_from("ble")
                elif among_var == 13:
                    self.slice_from("og")
                elif among_var == 14:
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "l":
                        raise lab0()
                    self.cursor -= 1
                    self.slice_from("og")
                elif among_var == 15:
                    self.slice_from("less")
                else:
                    if not self.in_grouping_b(EnglishStemmer.g_valid_LI):
                        raise lab0()
                    self.slice_del()
            except lab0: pass
            self.cursor = self.limit - v_22
            v_23 = self.limit - self.cursor
            try:
                self.ket = self.cursor
                among_var = self.find_among_b(EnglishStemmer.a_8)
                if among_var == 0:
                    raise lab0()
                self.bra = self.cursor
                if I_p1 > self.cursor:
                    raise lab0()
                if among_var == 1:
                    self.slice_from("tion")
                elif among_var == 2:
                    self.slice_from("ate")
                elif among_var == 3:
                    self.slice_from("al")
                elif among_var == 4:
                    self.slice_from("ic")
                elif among_var == 5:
                    self.slice_del()
                else:
                    if I_p2 > self.cursor:
                        raise lab0()
                    self.slice_del()
            except lab0: pass
            self.cursor = self.limit - v_23
            v_24 = self.limit - self.cursor
            try:
                self.ket = self.cursor
                among_var = self.find_among_b(EnglishStemmer.a_9)
                if among_var == 0:
                    raise lab0()
                self.bra = self.cursor
                if I_p2 > self.cursor:
                    raise lab0()
                if among_var == 1:
                    self.slice_del()
                else:
                    while True:
                        try:
                            if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "s":
                                raise lab1()
                            self.cursor -= 1
                            break
                        except lab1: pass
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "t":
                            raise lab0()
                        self.cursor -= 1
                        break
                    self.slice_del()
            except lab0: pass
            self.cursor = self.limit - v_24
            v_25 = self.limit - self.cursor
            try:
                self.ket = self.cursor
                among_var = self.find_among_b(EnglishStemmer.a_10)
                if among_var == 0:
                    raise lab0()
                self.bra = self.cursor
                if among_var == 1:
                    while True:
                        try:
                            if I_p2 > self.cursor:
                                raise lab1()
                            break
                        except lab1: pass
                        if I_p1 > self.cursor:
                            raise lab0()
                        v_26 = self.limit - self.cursor
                        try:
                            if not self.__r_shortv():
                                raise lab1()
                            raise lab0()
                        except lab1: pass
                        self.cursor = self.limit - v_26
                        break
                    self.slice_del()
                else:
                    if I_p2 > self.cursor:
                        raise lab0()
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "l":
                        raise lab0()
                    self.cursor -= 1
                    self.slice_del()
            except lab0: pass
            self.cursor = self.limit - v_25
            self.cursor = self.limit_backward
            v_27 = self.cursor
            try:
                if not B_Y_found:
                    raise lab0()
                while True:
                    v_28 = self.cursor
                    try:
                        while True:
                            v_29 = self.cursor
                            try:
                                self.bra = self.cursor
                                if self.cursor == self.limit or self.current[self.cursor] != "Y":
                                    raise lab2()
                                self.cursor += 1
                                self.ket = self.cursor
                                self.cursor = v_29
                                break
                            except lab2: pass
                            self.cursor = v_29
                            if self.cursor >= self.limit:
                                raise lab1()
                            self.cursor += 1
                        self.slice_from("y")
                        continue
                    except lab1: pass
                    self.cursor = v_28
                    break
            except lab0: pass
            self.cursor = v_27
            break
        return True

    a_0 = [
        Among("arsen", -1, -1),
        Among("commun", -1, -1),
        Among("emerg", -1, -1),
        Among("gener", -1, -1),
        Among("inter", -1, -1),
        Among("later", -1, -1),
        Among("organ", -1, -1),
        Among("past", -1, -1),
        Among("univers", -1, -1)
    ]

    a_1 = [
        Among("'", -1, 1),
        Among("'s'", 0, 1),
        Among("'s", -1, 1)
    ]

    a_2 = [
        Among("ied", -1, 2),
        Among("s", -1, 3),
        Among("ies", 1, 2),
        Among("sses", 1, 1),
        Among("ss", 1, -1),
        Among("us", 1, -1)
    ]

    a_3 = [
        Among("succ", -1, 1),
        Among("proc", -1, 1),
        Among("exc", -1, 1)
    ]

    a_4 = [
        Among("even", -1, 2),
        Among("cann", -1, 2),
        Among("inn", -1, 2),
        Among("earr", -1, 2),
        Among("herr", -1, 2),
        Among("out", -1, 2),
        Among("y", -1, 1)
    ]

    a_5 = [
        Among("", -1, -1),
        Among("ed", 0, 2),
        Among("eed", 1, 1),
        Among("ing", 0, 3),
        Among("edly", 0, 2),
        Among("eedly", 4, 1),
        Among("ingly", 0, 2)
    ]

    a_6 = [
        Among("", -1, 3),
        Among("bb", 0, 2),
        Among("dd", 0, 2),
        Among("ff", 0, 2),
        Among("gg", 0, 2),
        Among("bl", 0, 1),
        Among("mm", 0, 2),
        Among("nn", 0, 2),
        Among("pp", 0, 2),
        Among("rr", 0, 2),
        Among("at", 0, 1),
        Among("tt", 0, 2),
        Among("iz", 0, 1)
    ]

    a_7 = [
        Among("anci", -1, 3),
        Among("enci", -1, 2),
        Among("ogi", -1, 14),
        Among("li", -1, 16),
        Among("bli", 3, 12),
        Among("abli", 4, 4),
        Among("alli", 3, 8),
        Among("fulli", 3, 9),
        Among("lessli", 3, 15),
        Among("ousli", 3, 10),
        Among("entli", 3, 5),
        Among("aliti", -1, 8),
        Among("biliti", -1, 12),
        Among("iviti", -1, 11),
        Among("tional", -1, 1),
        Among("ational", 14, 7),
        Among("alism", -1, 8),
        Among("ation", -1, 7),
        Among("ization", 17, 6),
        Among("izer", -1, 6),
        Among("ator", -1, 7),
        Among("iveness", -1, 11),
        Among("fulness", -1, 9),
        Among("ousness", -1, 10),
        Among("ogist", -1, 13)
    ]

    a_8 = [
        Among("icate", -1, 4),
        Among("ative", -1, 6),
        Among("alize", -1, 3),
        Among("iciti", -1, 4),
        Among("ical", -1, 4),
        Among("tional", -1, 1),
        Among("ational", 5, 2),
        Among("ful", -1, 5),
        Among("ness", -1, 5)
    ]

    a_9 = [
        Among("ic", -1, 1),
        Among("ance", -1, 1),
        Among("ence", -1, 1),
        Among("able", -1, 1),
        Among("ible", -1, 1),
        Among("ate", -1, 1),
        Among("ive", -1, 1),
        Among("ize", -1, 1),
        Among("iti", -1, 1),
        Among("al", -1, 1),
        Among("ism", -1, 1),
        Among("ion", -1, 2),
        Among("er", -1, 1),
        Among("ous", -1, 1),
        Among("ant", -1, 1),
        Among("ent", -1, 1),
        Among("ment", 15, 1),
        Among("ement", 16, 1)
    ]

    a_10 = [
        Among("e", -1, 1),
        Among("l", -1, 2)
    ]

    a_11 = [
        Among("andes", -1, -1),
        Among("atlas", -1, -1),
        Among("bias", -1, -1),
        Among("cosmos", -1, -1),
        Among("early", -1, 6),
        Among("gently", -1, 4),
        Among("howe", -1, -1),
        Among("idly", -1, 3),
        Among("news", -1, -1),
        Among("only", -1, 7),
        Among("singly", -1, 8),
        Among("skies", -1, 2),
        Among("skis", -1, 1),
        Among("sky", -1, -1),
        Among("ugly", -1, 5)
    ]
    as_11 = ("ski", "sky", "idl", "gentl", "ugli", "earli", "onli", "singl")


class lab0(BaseException): pass


class lab1(BaseException): pass


class lab2(BaseException): pass


class lab3(BaseException): pass
