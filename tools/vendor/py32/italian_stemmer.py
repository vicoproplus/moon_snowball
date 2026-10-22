# Generated from italian.sbl by Snowball 3.2.0 - https://snowballstem.org/

from .basestemmer import BaseStemmer
from .among import Among


class ItalianStemmer(BaseStemmer):
    '''
    This class implements the stemming algorithm defined by a snowball script.
    Generated from italian.sbl by Snowball 3.2.0 - https://snowballstem.org/
    '''

    g_v = {"a", "e", "i", "o", "u", "à", "è", "ì", "ò", "ù"}

    g_AEIO = {"a", "e", "i", "o", "à", "è", "ì", "ò"}

    g_CG = "cg"

    def _stem(self):
        v_1 = self.cursor
        try:
            self.bra = self.cursor
            if self.find_among(ItalianStemmer.a_0) == 0:
                raise lab0()
            self.ket = self.cursor
            if self.cursor >= self.limit:
                raise lab0()
            self.slice_del()
        except lab0: pass
        self.cursor = v_1
        v_2 = self.cursor
        try:
            v_3 = self.cursor
            while True:
                v_4 = self.cursor
                try:
                    self.bra = self.cursor
                    among_var = self.find_among(ItalianStemmer.a_1)
                    self.ket = self.cursor
                    if among_var == 1:
                        self.slice_from("à")
                    elif among_var == 2:
                        self.slice_from("è")
                    elif among_var == 3:
                        self.slice_from("ì")
                    elif among_var == 4:
                        self.slice_from("ò")
                    elif among_var == 5:
                        self.slice_from("ù")
                    elif among_var == 6:
                        self.slice_from("qU")
                    else:
                        if self.cursor >= self.limit:
                            raise lab1()
                        self.cursor += 1
                    continue
                except lab1: pass
                self.cursor = v_4
                break
            self.cursor = v_3
            while True:
                v_5 = self.cursor
                try:
                    while True:
                        v_6 = self.cursor
                        try:
                            if not self.in_grouping(ItalianStemmer.g_v):
                                raise lab2()
                            self.bra = self.cursor
                            while True:
                                v_7 = self.cursor
                                try:
                                    if self.cursor == self.limit or self.current[self.cursor] != "u":
                                        raise lab3()
                                    self.cursor += 1
                                    self.ket = self.cursor
                                    if not self.in_grouping(ItalianStemmer.g_v):
                                        raise lab3()
                                    self.slice_from("U")
                                    break
                                except lab3: pass
                                self.cursor = v_7
                                if self.cursor == self.limit or self.current[self.cursor] != "i":
                                    raise lab2()
                                self.cursor += 1
                                self.ket = self.cursor
                                if not self.in_grouping(ItalianStemmer.g_v):
                                    raise lab2()
                                self.slice_from("I")
                                break
                            self.cursor = v_6
                            break
                        except lab2: pass
                        self.cursor = v_6
                        if self.cursor >= self.limit:
                            raise lab1()
                        self.cursor += 1
                    continue
                except lab1: pass
                self.cursor = v_5
                break
        except lab0: pass
        self.cursor = v_2
        try:
            I_pV = self.limit
            I_p1 = self.limit
            I_p2 = self.limit
            v_8 = self.cursor
            try:
                while True:
                    v_9 = self.cursor
                    try:
                        if not self.in_grouping(ItalianStemmer.g_v):
                            raise lab2()
                        while True:
                            v_10 = self.cursor
                            try:
                                if not self.out_grouping(ItalianStemmer.g_v):
                                    raise lab3()
                                if not self.go_out_grouping(ItalianStemmer.g_v):
                                    raise lab3()
                                self.cursor += 1
                                break
                            except lab3: pass
                            self.cursor = v_10
                            if not self.in_grouping(ItalianStemmer.g_v):
                                raise lab2()
                            if not self.go_in_grouping(ItalianStemmer.g_v):
                                raise lab2()
                            self.cursor += 1
                            break
                        break
                    except lab2: pass
                    self.cursor = v_9
                    try:
                        if not self.eq_s("divan"):
                            raise lab2()
                        break
                    except lab2: pass
                    self.cursor = v_9
                    if not self.out_grouping(ItalianStemmer.g_v):
                        raise lab1()
                    while True:
                        v_11 = self.cursor
                        try:
                            if not self.out_grouping(ItalianStemmer.g_v):
                                raise lab2()
                            if not self.go_out_grouping(ItalianStemmer.g_v):
                                raise lab2()
                            self.cursor += 1
                            break
                        except lab2: pass
                        self.cursor = v_11
                        if not self.in_grouping(ItalianStemmer.g_v):
                            raise lab1()
                        if self.cursor >= self.limit:
                            raise lab1()
                        self.cursor += 1
                        break
                    break
                I_pV = self.cursor
            except lab1: pass
            self.cursor = v_8
            v_12 = self.cursor
            try:
                if not self.go_out_grouping(ItalianStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                if not self.go_in_grouping(ItalianStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                I_p1 = self.cursor
                if not self.go_out_grouping(ItalianStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                if not self.go_in_grouping(ItalianStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                I_p2 = self.cursor
            except lab1: pass
            self.cursor = v_12
        except lab0: pass
        self.limit_backward = self.cursor
        self.cursor = self.limit
        v_13 = self.limit - self.cursor
        try:
            self.ket = self.cursor
            if self.find_among_b(ItalianStemmer.a_3) == 0:
                raise lab0()
            self.bra = self.cursor
            among_var = self.find_among_b(ItalianStemmer.a_4)
            if among_var == 0:
                raise lab0()
            if I_pV > self.cursor:
                raise lab0()
            self.slice_from(ItalianStemmer.as_4[among_var - 1])
        except lab0: pass
        self.cursor = self.limit - v_13
        v_14 = self.limit - self.cursor
        try:
            while True:
                v_15 = self.limit - self.cursor
                try:
                    self.ket = self.cursor
                    among_var = self.find_among_b(ItalianStemmer.a_7)
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
                        v_16 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            if not self.eq_s_b("ic"):
                                self.cursor = self.limit - v_16
                                raise lab2()
                            self.bra = self.cursor
                            if I_p2 > self.cursor:
                                self.cursor = self.limit - v_16
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
                        if I_pV > self.cursor:
                            raise lab1()
                        self.slice_del()
                    elif among_var == 7:
                        if I_p1 > self.cursor:
                            raise lab1()
                        self.slice_del()
                        v_17 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            among_var = self.find_among_b(ItalianStemmer.a_5)
                            if among_var == 0:
                                self.cursor = self.limit - v_17
                                raise lab2()
                            self.bra = self.cursor
                            if I_p2 > self.cursor:
                                self.cursor = self.limit - v_17
                                raise lab2()
                            self.slice_del()
                            if among_var == 1:
                                self.ket = self.cursor
                                if not self.eq_s_b("at"):
                                    self.cursor = self.limit - v_17
                                    raise lab2()
                                self.bra = self.cursor
                                if I_p2 > self.cursor:
                                    self.cursor = self.limit - v_17
                                    raise lab2()
                                self.slice_del()
                        except lab2: pass
                    elif among_var == 8:
                        if I_p2 > self.cursor:
                            raise lab1()
                        self.slice_del()
                        v_18 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            if self.find_among_b(ItalianStemmer.a_6) == 0:
                                self.cursor = self.limit - v_18
                                raise lab2()
                            self.bra = self.cursor
                            if I_p2 > self.cursor:
                                self.cursor = self.limit - v_18
                                raise lab2()
                            self.slice_del()
                        except lab2: pass
                    else:
                        if I_p2 > self.cursor:
                            raise lab1()
                        self.slice_del()
                        v_19 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            if not self.eq_s_b("at"):
                                self.cursor = self.limit - v_19
                                raise lab2()
                            self.bra = self.cursor
                            if I_p2 > self.cursor:
                                self.cursor = self.limit - v_19
                                raise lab2()
                            self.slice_del()
                            self.ket = self.cursor
                            if not self.eq_s_b("ic"):
                                self.cursor = self.limit - v_19
                                raise lab2()
                            self.bra = self.cursor
                            if I_p2 > self.cursor:
                                self.cursor = self.limit - v_19
                                raise lab2()
                            self.slice_del()
                        except lab2: pass
                    break
                except lab1: pass
                self.cursor = self.limit - v_15
                if self.cursor < I_pV:
                    raise lab0()
                v_21 = self.limit_backward
                self.limit_backward = I_pV
                self.ket = self.cursor
                if self.find_among_b(ItalianStemmer.a_8) == 0:
                    self.limit_backward = v_21
                    raise lab0()
                self.bra = self.cursor
                self.slice_del()
                self.limit_backward = v_21
                break
        except lab0: pass
        self.cursor = self.limit - v_14
        v_22 = self.limit - self.cursor
        try:
            v_23 = self.limit - self.cursor
            try:
                self.ket = self.cursor
                if not self.in_grouping_b(ItalianStemmer.g_AEIO):
                    self.cursor = self.limit - v_23
                    raise lab1()
                self.bra = self.cursor
                if I_pV > self.cursor:
                    self.cursor = self.limit - v_23
                    raise lab1()
                self.slice_del()
                self.ket = self.cursor
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "i":
                    self.cursor = self.limit - v_23
                    raise lab1()
                self.cursor -= 1
                self.bra = self.cursor
                if I_pV > self.cursor:
                    self.cursor = self.limit - v_23
                    raise lab1()
                self.slice_del()
            except lab1: pass
            v_24 = self.limit - self.cursor
            try:
                self.ket = self.cursor
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "h":
                    self.cursor = self.limit - v_24
                    raise lab1()
                self.cursor -= 1
                self.bra = self.cursor
                if not self.in_grouping_b(ItalianStemmer.g_CG):
                    self.cursor = self.limit - v_24
                    raise lab1()
                if I_pV > self.cursor:
                    self.cursor = self.limit - v_24
                    raise lab1()
                self.slice_del()
            except lab1: pass
        except lab0: pass
        self.cursor = self.limit - v_22
        self.cursor = self.limit_backward
        v_25 = self.cursor
        try:
            while True:
                v_26 = self.cursor
                try:
                    self.bra = self.cursor
                    among_var = self.find_among(ItalianStemmer.a_2)
                    self.ket = self.cursor
                    if among_var == 1:
                        self.slice_from("i")
                    elif among_var == 2:
                        self.slice_from("u")
                    else:
                        if self.cursor >= self.limit:
                            raise lab1()
                        self.cursor += 1
                    continue
                except lab1: pass
                self.cursor = v_26
                break
        except lab0: pass
        self.cursor = v_25
        return True

    a_0 = [
        Among("all'", -1, -1),
        Among("d'", -1, -1),
        Among("dall'", -1, -1),
        Among("dell'", -1, -1),
        Among("gl'", -1, -1),
        Among("l'", -1, -1),
        Among("m'", -1, -1),
        Among("nell'", -1, -1),
        Among("quell'", -1, -1),
        Among("quest'", -1, -1),
        Among("s'", -1, -1),
        Among("sull'", -1, -1),
        Among("t'", -1, -1),
        Among("tutt'", -1, -1),
        Among("un'", -1, -1),
        Among("v'", -1, -1)
    ]

    a_1 = [
        Among("", -1, 7),
        Among("qu", 0, 6),
        Among("á", 0, 1),
        Among("é", 0, 2),
        Among("í", 0, 3),
        Among("ó", 0, 4),
        Among("ú", 0, 5)
    ]

    a_2 = [
        Among("", -1, 3),
        Among("I", 0, 1),
        Among("U", 0, 2)
    ]

    a_3 = [
        Among("la", -1, -1),
        Among("cela", 0, -1),
        Among("gliela", 0, -1),
        Among("mela", 0, -1),
        Among("tela", 0, -1),
        Among("vela", 0, -1),
        Among("le", -1, -1),
        Among("cele", 6, -1),
        Among("gliele", 6, -1),
        Among("mele", 6, -1),
        Among("tele", 6, -1),
        Among("vele", 6, -1),
        Among("ne", -1, -1),
        Among("cene", 12, -1),
        Among("gliene", 12, -1),
        Among("mene", 12, -1),
        Among("sene", 12, -1),
        Among("tene", 12, -1),
        Among("vene", 12, -1),
        Among("ci", -1, -1),
        Among("li", -1, -1),
        Among("celi", 20, -1),
        Among("glieli", 20, -1),
        Among("meli", 20, -1),
        Among("teli", 20, -1),
        Among("veli", 20, -1),
        Among("gli", 20, -1),
        Among("mi", -1, -1),
        Among("si", -1, -1),
        Among("ti", -1, -1),
        Among("vi", -1, -1),
        Among("lo", -1, -1),
        Among("celo", 31, -1),
        Among("glielo", 31, -1),
        Among("melo", 31, -1),
        Among("telo", 31, -1),
        Among("velo", 31, -1)
    ]

    a_4 = [
        Among("ando", -1, 1),
        Among("endo", -1, 1),
        Among("ar", -1, 2),
        Among("er", -1, 2),
        Among("ir", -1, 2)
    ]
    as_4 = ("", "e")

    a_5 = [
        Among("ic", -1, -1),
        Among("abil", -1, -1),
        Among("os", -1, -1),
        Among("iv", -1, 1)
    ]

    a_6 = [
        Among("ic", -1, 1),
        Among("abil", -1, 1),
        Among("iv", -1, 1)
    ]

    a_7 = [
        Among("ica", -1, 1),
        Among("logia", -1, 3),
        Among("osa", -1, 1),
        Among("ista", -1, 1),
        Among("iva", -1, 9),
        Among("anza", -1, 1),
        Among("enza", -1, 5),
        Among("ice", -1, 1),
        Among("atrice", 7, 1),
        Among("iche", -1, 1),
        Among("logie", -1, 3),
        Among("abile", -1, 1),
        Among("ibile", -1, 1),
        Among("usione", -1, 4),
        Among("azione", -1, 2),
        Among("uzione", -1, 4),
        Among("atore", -1, 2),
        Among("ose", -1, 1),
        Among("ante", -1, 1),
        Among("mente", -1, 1),
        Among("amente", 19, 7),
        Among("iste", -1, 1),
        Among("ive", -1, 9),
        Among("anze", -1, 1),
        Among("enze", -1, 5),
        Among("ici", -1, 1),
        Among("atrici", 25, 1),
        Among("ichi", -1, 1),
        Among("abili", -1, 1),
        Among("ibili", -1, 1),
        Among("ismi", -1, 1),
        Among("usioni", -1, 4),
        Among("azioni", -1, 2),
        Among("uzioni", -1, 4),
        Among("atori", -1, 2),
        Among("osi", -1, 1),
        Among("anti", -1, 1),
        Among("amenti", -1, 6),
        Among("imenti", -1, 6),
        Among("isti", -1, 1),
        Among("ivi", -1, 9),
        Among("ico", -1, 1),
        Among("ismo", -1, 1),
        Among("oso", -1, 1),
        Among("amento", -1, 6),
        Among("imento", -1, 6),
        Among("ivo", -1, 9),
        Among("ità", -1, 8),
        Among("istà", -1, 1),
        Among("istè", -1, 1),
        Among("istì", -1, 1)
    ]

    a_8 = [
        Among("isca", -1, 1),
        Among("enda", -1, 1),
        Among("ata", -1, 1),
        Among("ita", -1, 1),
        Among("uta", -1, 1),
        Among("ava", -1, 1),
        Among("eva", -1, 1),
        Among("iva", -1, 1),
        Among("erebbe", -1, 1),
        Among("irebbe", -1, 1),
        Among("isce", -1, 1),
        Among("ende", -1, 1),
        Among("are", -1, 1),
        Among("ere", -1, 1),
        Among("ire", -1, 1),
        Among("asse", -1, 1),
        Among("ate", -1, 1),
        Among("avate", 16, 1),
        Among("evate", 16, 1),
        Among("ivate", 16, 1),
        Among("ete", -1, 1),
        Among("erete", 20, 1),
        Among("irete", 20, 1),
        Among("ite", -1, 1),
        Among("ereste", -1, 1),
        Among("ireste", -1, 1),
        Among("ute", -1, 1),
        Among("erai", -1, 1),
        Among("irai", -1, 1),
        Among("isci", -1, 1),
        Among("endi", -1, 1),
        Among("erei", -1, 1),
        Among("irei", -1, 1),
        Among("assi", -1, 1),
        Among("ati", -1, 1),
        Among("iti", -1, 1),
        Among("eresti", -1, 1),
        Among("iresti", -1, 1),
        Among("uti", -1, 1),
        Among("avi", -1, 1),
        Among("evi", -1, 1),
        Among("ivi", -1, 1),
        Among("isco", -1, 1),
        Among("ando", -1, 1),
        Among("endo", -1, 1),
        Among("Yamo", -1, 1),
        Among("iamo", -1, 1),
        Among("avamo", -1, 1),
        Among("evamo", -1, 1),
        Among("ivamo", -1, 1),
        Among("eremo", -1, 1),
        Among("iremo", -1, 1),
        Among("assimo", -1, 1),
        Among("ammo", -1, 1),
        Among("emmo", -1, 1),
        Among("eremmo", 54, 1),
        Among("iremmo", 54, 1),
        Among("immo", -1, 1),
        Among("ano", -1, 1),
        Among("iscano", 58, 1),
        Among("avano", 58, 1),
        Among("evano", 58, 1),
        Among("ivano", 58, 1),
        Among("eranno", -1, 1),
        Among("iranno", -1, 1),
        Among("ono", -1, 1),
        Among("iscono", 65, 1),
        Among("arono", 65, 1),
        Among("erono", 65, 1),
        Among("irono", 65, 1),
        Among("erebbero", -1, 1),
        Among("irebbero", -1, 1),
        Among("assero", -1, 1),
        Among("essero", -1, 1),
        Among("issero", -1, 1),
        Among("ato", -1, 1),
        Among("ito", -1, 1),
        Among("uto", -1, 1),
        Among("avo", -1, 1),
        Among("evo", -1, 1),
        Among("ivo", -1, 1),
        Among("ar", -1, 1),
        Among("ir", -1, 1),
        Among("erà", -1, 1),
        Among("irà", -1, 1),
        Among("erò", -1, 1),
        Among("irò", -1, 1)
    ]


class lab0(BaseException): pass


class lab1(BaseException): pass


class lab2(BaseException): pass


class lab3(BaseException): pass
