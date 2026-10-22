# Generated from spanish.sbl by Snowball 3.2.0 - https://snowballstem.org/

from .basestemmer import BaseStemmer
from .among import Among


class SpanishStemmer(BaseStemmer):
    '''
    This class implements the stemming algorithm defined by a snowball script.
    Generated from spanish.sbl by Snowball 3.2.0 - https://snowballstem.org/
    '''

    g_v = {"a", "e", "i", "o", "u", "á", "é", "í", "ó", "ú", "ü"}


    def _stem(self):
        try:
            I_pV = self.limit
            I_p1 = self.limit
            I_p2 = self.limit
            v_1 = self.cursor
            try:
                while True:
                    v_2 = self.cursor
                    try:
                        if not self.in_grouping(SpanishStemmer.g_v):
                            raise lab2()
                        while True:
                            v_3 = self.cursor
                            try:
                                if not self.out_grouping(SpanishStemmer.g_v):
                                    raise lab3()
                                if not self.go_out_grouping(SpanishStemmer.g_v):
                                    raise lab3()
                                self.cursor += 1
                                break
                            except lab3: pass
                            self.cursor = v_3
                            if not self.in_grouping(SpanishStemmer.g_v):
                                raise lab2()
                            if not self.go_in_grouping(SpanishStemmer.g_v):
                                raise lab2()
                            self.cursor += 1
                            break
                        break
                    except lab2: pass
                    self.cursor = v_2
                    if not self.out_grouping(SpanishStemmer.g_v):
                        raise lab1()
                    while True:
                        v_4 = self.cursor
                        try:
                            if not self.out_grouping(SpanishStemmer.g_v):
                                raise lab2()
                            if not self.go_out_grouping(SpanishStemmer.g_v):
                                raise lab2()
                            self.cursor += 1
                            break
                        except lab2: pass
                        self.cursor = v_4
                        if not self.in_grouping(SpanishStemmer.g_v):
                            raise lab1()
                        if self.cursor >= self.limit:
                            raise lab1()
                        self.cursor += 1
                        break
                    break
                I_pV = self.cursor
            except lab1: pass
            self.cursor = v_1
            v_5 = self.cursor
            try:
                if not self.go_out_grouping(SpanishStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                if not self.go_in_grouping(SpanishStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                I_p1 = self.cursor
                if not self.go_out_grouping(SpanishStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                if not self.go_in_grouping(SpanishStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                I_p2 = self.cursor
            except lab1: pass
            self.cursor = v_5
        except lab0: pass
        self.limit_backward = self.cursor
        self.cursor = self.limit
        v_6 = self.limit - self.cursor
        try:
            self.ket = self.cursor
            if self.find_among_b(SpanishStemmer.a_1) == 0:
                raise lab0()
            self.bra = self.cursor
            among_var = self.find_among_b(SpanishStemmer.a_2)
            if among_var == 0:
                raise lab0()
            if I_pV > self.cursor:
                raise lab0()
            if among_var == 1:
                self.bra = self.cursor
                self.slice_from("iendo")
            elif among_var == 2:
                self.bra = self.cursor
                self.slice_from("ando")
            elif among_var == 3:
                self.bra = self.cursor
                self.slice_from("ar")
            elif among_var == 4:
                self.bra = self.cursor
                self.slice_from("er")
            elif among_var == 5:
                self.bra = self.cursor
                self.slice_from("ir")
            elif among_var == 6:
                self.slice_del()
            else:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "u":
                    raise lab0()
                self.cursor -= 1
                self.slice_del()
        except lab0: pass
        self.cursor = self.limit - v_6
        v_7 = self.limit - self.cursor
        try:
            while True:
                v_8 = self.limit - self.cursor
                try:
                    self.ket = self.cursor
                    among_var = self.find_among_b(SpanishStemmer.a_6)
                    if among_var == 0:
                        raise lab1()
                    self.bra = self.cursor
                    if among_var == 1:
                        if I_p2 > self.cursor:
                            raise lab1()
                        self.slice_del()
                    elif among_var == 2:
                        if I_p2 > self.cursor:
                            raise lab1()
                        self.slice_del()
                        v_9 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            if not self.eq_s_b("ic"):
                                self.cursor = self.limit - v_9
                                raise lab2()
                            self.bra = self.cursor
                            if I_p2 > self.cursor:
                                self.cursor = self.limit - v_9
                                raise lab2()
                            self.slice_del()
                        except lab2: pass
                    elif among_var == 3:
                        if I_p2 > self.cursor:
                            raise lab1()
                        self.slice_from("log")
                    elif among_var == 4:
                        if I_p2 > self.cursor:
                            raise lab1()
                        self.slice_from("u")
                    elif among_var == 5:
                        if I_p2 > self.cursor:
                            raise lab1()
                        self.slice_from("ente")
                    elif among_var == 6:
                        if I_p1 > self.cursor:
                            raise lab1()
                        self.slice_del()
                        v_10 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            among_var = self.find_among_b(SpanishStemmer.a_3)
                            if among_var == 0:
                                self.cursor = self.limit - v_10
                                raise lab2()
                            self.bra = self.cursor
                            if I_p2 > self.cursor:
                                self.cursor = self.limit - v_10
                                raise lab2()
                            self.slice_del()
                            if among_var == 1:
                                self.ket = self.cursor
                                if not self.eq_s_b("at"):
                                    self.cursor = self.limit - v_10
                                    raise lab2()
                                self.bra = self.cursor
                                if I_p2 > self.cursor:
                                    self.cursor = self.limit - v_10
                                    raise lab2()
                                self.slice_del()
                        except lab2: pass
                    elif among_var == 7:
                        if I_p2 > self.cursor:
                            raise lab1()
                        self.slice_del()
                        v_11 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            if self.find_among_b(SpanishStemmer.a_4) == 0:
                                self.cursor = self.limit - v_11
                                raise lab2()
                            self.bra = self.cursor
                            if I_p2 > self.cursor:
                                self.cursor = self.limit - v_11
                                raise lab2()
                            self.slice_del()
                        except lab2: pass
                    elif among_var == 8:
                        if I_p2 > self.cursor:
                            raise lab1()
                        self.slice_del()
                        v_12 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            if self.find_among_b(SpanishStemmer.a_5) == 0:
                                self.cursor = self.limit - v_12
                                raise lab2()
                            self.bra = self.cursor
                            if I_p2 > self.cursor:
                                self.cursor = self.limit - v_12
                                raise lab2()
                            self.slice_del()
                        except lab2: pass
                    else:
                        if I_p2 > self.cursor:
                            raise lab1()
                        self.slice_del()
                        v_13 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            if not self.eq_s_b("at"):
                                self.cursor = self.limit - v_13
                                raise lab2()
                            self.bra = self.cursor
                            if I_p2 > self.cursor:
                                self.cursor = self.limit - v_13
                                raise lab2()
                            self.slice_del()
                        except lab2: pass
                    break
                except lab1: pass
                self.cursor = self.limit - v_8
                try:
                    if self.cursor < I_pV:
                        raise lab1()
                    v_15 = self.limit_backward
                    self.limit_backward = I_pV
                    self.ket = self.cursor
                    if self.find_among_b(SpanishStemmer.a_7) == 0:
                        self.limit_backward = v_15
                        raise lab1()
                    self.bra = self.cursor
                    self.limit_backward = v_15
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "u":
                        raise lab1()
                    self.cursor -= 1
                    self.slice_del()
                    break
                except lab1: pass
                self.cursor = self.limit - v_8
                if self.cursor < I_pV:
                    raise lab0()
                v_17 = self.limit_backward
                self.limit_backward = I_pV
                self.ket = self.cursor
                among_var = self.find_among_b(SpanishStemmer.a_8)
                if among_var == 0:
                    self.limit_backward = v_17
                    raise lab0()
                self.bra = self.cursor
                self.limit_backward = v_17
                if among_var == 1:
                    v_18 = self.limit - self.cursor
                    try:
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "u":
                            self.cursor = self.limit - v_18
                            raise lab1()
                        self.cursor -= 1
                        v_19 = self.limit - self.cursor
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "g":
                            self.cursor = self.limit - v_18
                            raise lab1()
                        self.cursor -= 1
                        self.cursor = self.limit - v_19
                    except lab1: pass
                    self.bra = self.cursor
                    self.slice_del()
                else:
                    self.slice_del()
                break
        except lab0: pass
        self.cursor = self.limit - v_7
        v_20 = self.limit - self.cursor
        try:
            self.ket = self.cursor
            among_var = self.find_among_b(SpanishStemmer.a_9)
            if among_var == 0:
                raise lab0()
            self.bra = self.cursor
            if among_var == 1:
                if I_pV > self.cursor:
                    raise lab0()
                self.slice_del()
            else:
                if I_pV > self.cursor:
                    raise lab0()
                self.slice_del()
                v_21 = self.limit - self.cursor
                try:
                    self.ket = self.cursor
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "u":
                        self.cursor = self.limit - v_21
                        raise lab1()
                    self.cursor -= 1
                    self.bra = self.cursor
                    v_22 = self.limit - self.cursor
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "g":
                        self.cursor = self.limit - v_21
                        raise lab1()
                    self.cursor -= 1
                    self.cursor = self.limit - v_22
                    if I_pV > self.cursor:
                        self.cursor = self.limit - v_21
                        raise lab1()
                    self.slice_del()
                except lab1: pass
        except lab0: pass
        self.cursor = self.limit - v_20
        self.cursor = self.limit_backward
        v_23 = self.cursor
        try:
            while True:
                v_24 = self.cursor
                try:
                    self.bra = self.cursor
                    among_var = self.find_among(SpanishStemmer.a_0)
                    self.ket = self.cursor
                    if among_var == 1:
                        self.slice_from("a")
                    elif among_var == 2:
                        self.slice_from("e")
                    elif among_var == 3:
                        self.slice_from("i")
                    elif among_var == 4:
                        self.slice_from("o")
                    elif among_var == 5:
                        self.slice_from("u")
                    else:
                        if self.cursor >= self.limit:
                            raise lab1()
                        self.cursor += 1
                    continue
                except lab1: pass
                self.cursor = v_24
                break
        except lab0: pass
        self.cursor = v_23
        return True

    a_0 = [
        Among("", -1, 6),
        Among("á", 0, 1),
        Among("é", 0, 2),
        Among("í", 0, 3),
        Among("ó", 0, 4),
        Among("ú", 0, 5)
    ]

    a_1 = [
        Among("la", -1, -1),
        Among("sela", 0, -1),
        Among("le", -1, -1),
        Among("me", -1, -1),
        Among("se", -1, -1),
        Among("lo", -1, -1),
        Among("selo", 5, -1),
        Among("las", -1, -1),
        Among("selas", 7, -1),
        Among("les", -1, -1),
        Among("los", -1, -1),
        Among("selos", 10, -1),
        Among("nos", -1, -1)
    ]

    a_2 = [
        Among("ando", -1, 6),
        Among("iendo", -1, 6),
        Among("yendo", -1, 7),
        Among("ándo", -1, 2),
        Among("iéndo", -1, 1),
        Among("ar", -1, 6),
        Among("er", -1, 6),
        Among("ir", -1, 6),
        Among("ár", -1, 3),
        Among("ér", -1, 4),
        Among("ír", -1, 5)
    ]

    a_3 = [
        Among("ic", -1, -1),
        Among("ad", -1, -1),
        Among("os", -1, -1),
        Among("iv", -1, 1)
    ]

    a_4 = [
        Among("able", -1, 1),
        Among("ible", -1, 1),
        Among("ante", -1, 1)
    ]

    a_5 = [
        Among("ic", -1, 1),
        Among("abil", -1, 1),
        Among("iv", -1, 1)
    ]

    a_6 = [
        Among("ica", -1, 1),
        Among("ancia", -1, 2),
        Among("encia", -1, 5),
        Among("adora", -1, 2),
        Among("osa", -1, 1),
        Among("ista", -1, 1),
        Among("iva", -1, 9),
        Among("anza", -1, 1),
        Among("logía", -1, 3),
        Among("idad", -1, 8),
        Among("able", -1, 1),
        Among("ible", -1, 1),
        Among("ante", -1, 2),
        Among("mente", -1, 7),
        Among("amente", 13, 6),
        Among("acion", -1, 2),
        Among("ucion", -1, 4),
        Among("ación", -1, 2),
        Among("ución", -1, 4),
        Among("ico", -1, 1),
        Among("ismo", -1, 1),
        Among("oso", -1, 1),
        Among("amiento", -1, 1),
        Among("imiento", -1, 1),
        Among("ivo", -1, 9),
        Among("ador", -1, 2),
        Among("icas", -1, 1),
        Among("ancias", -1, 2),
        Among("encias", -1, 5),
        Among("adoras", -1, 2),
        Among("osas", -1, 1),
        Among("istas", -1, 1),
        Among("ivas", -1, 9),
        Among("anzas", -1, 1),
        Among("logías", -1, 3),
        Among("idades", -1, 8),
        Among("ables", -1, 1),
        Among("ibles", -1, 1),
        Among("aciones", -1, 2),
        Among("uciones", -1, 4),
        Among("adores", -1, 2),
        Among("antes", -1, 2),
        Among("icos", -1, 1),
        Among("ismos", -1, 1),
        Among("osos", -1, 1),
        Among("amientos", -1, 1),
        Among("imientos", -1, 1),
        Among("ivos", -1, 9)
    ]

    a_7 = [
        Among("ya", -1, 1),
        Among("ye", -1, 1),
        Among("yan", -1, 1),
        Among("yen", -1, 1),
        Among("yeron", -1, 1),
        Among("yendo", -1, 1),
        Among("yo", -1, 1),
        Among("yas", -1, 1),
        Among("yes", -1, 1),
        Among("yais", -1, 1),
        Among("yamos", -1, 1),
        Among("yó", -1, 1)
    ]

    a_8 = [
        Among("aba", -1, 2),
        Among("ada", -1, 2),
        Among("ida", -1, 2),
        Among("ara", -1, 2),
        Among("iera", -1, 2),
        Among("ía", -1, 2),
        Among("aría", 5, 2),
        Among("ería", 5, 2),
        Among("iría", 5, 2),
        Among("ad", -1, 2),
        Among("ed", -1, 2),
        Among("id", -1, 2),
        Among("ase", -1, 2),
        Among("iese", -1, 2),
        Among("aste", -1, 2),
        Among("iste", -1, 2),
        Among("an", -1, 2),
        Among("aban", 16, 2),
        Among("aran", 16, 2),
        Among("ieran", 16, 2),
        Among("ían", 16, 2),
        Among("arían", 20, 2),
        Among("erían", 20, 2),
        Among("irían", 20, 2),
        Among("en", -1, 1),
        Among("asen", 24, 2),
        Among("iesen", 24, 2),
        Among("aron", -1, 2),
        Among("ieron", -1, 2),
        Among("arán", -1, 2),
        Among("erán", -1, 2),
        Among("irán", -1, 2),
        Among("ado", -1, 2),
        Among("ido", -1, 2),
        Among("ando", -1, 2),
        Among("iendo", -1, 2),
        Among("ar", -1, 2),
        Among("er", -1, 2),
        Among("ir", -1, 2),
        Among("as", -1, 2),
        Among("abas", 39, 2),
        Among("adas", 39, 2),
        Among("idas", 39, 2),
        Among("aras", 39, 2),
        Among("ieras", 39, 2),
        Among("ías", 39, 2),
        Among("arías", 45, 2),
        Among("erías", 45, 2),
        Among("irías", 45, 2),
        Among("es", -1, 1),
        Among("ases", 49, 2),
        Among("ieses", 49, 2),
        Among("abais", -1, 2),
        Among("arais", -1, 2),
        Among("ierais", -1, 2),
        Among("íais", -1, 2),
        Among("aríais", 55, 2),
        Among("eríais", 55, 2),
        Among("iríais", 55, 2),
        Among("aseis", -1, 2),
        Among("ieseis", -1, 2),
        Among("asteis", -1, 2),
        Among("isteis", -1, 2),
        Among("áis", -1, 2),
        Among("éis", -1, 1),
        Among("aréis", 64, 2),
        Among("eréis", 64, 2),
        Among("iréis", 64, 2),
        Among("ados", -1, 2),
        Among("idos", -1, 2),
        Among("amos", -1, 2),
        Among("ábamos", 70, 2),
        Among("áramos", 70, 2),
        Among("iéramos", 70, 2),
        Among("íamos", 70, 2),
        Among("aríamos", 74, 2),
        Among("eríamos", 74, 2),
        Among("iríamos", 74, 2),
        Among("emos", -1, 1),
        Among("aremos", 78, 2),
        Among("eremos", 78, 2),
        Among("iremos", 78, 2),
        Among("ásemos", 78, 2),
        Among("iésemos", 78, 2),
        Among("imos", -1, 2),
        Among("arás", -1, 2),
        Among("erás", -1, 2),
        Among("irás", -1, 2),
        Among("ís", -1, 2),
        Among("ará", -1, 2),
        Among("erá", -1, 2),
        Among("irá", -1, 2),
        Among("aré", -1, 2),
        Among("eré", -1, 2),
        Among("iré", -1, 2),
        Among("ió", -1, 2)
    ]

    a_9 = [
        Among("a", -1, 1),
        Among("e", -1, 2),
        Among("o", -1, 1),
        Among("os", -1, 1),
        Among("á", -1, 1),
        Among("é", -1, 2),
        Among("í", -1, 1),
        Among("ó", -1, 1)
    ]


class lab0(BaseException): pass


class lab1(BaseException): pass


class lab2(BaseException): pass


class lab3(BaseException): pass
