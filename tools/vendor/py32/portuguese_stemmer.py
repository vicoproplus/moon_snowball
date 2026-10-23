# Generated from portuguese.sbl by Snowball 3.2.0 - https://snowballstem.org/

from .basestemmer import BaseStemmer
from .among import Among


class PortugueseStemmer(BaseStemmer):
    '''
    This class implements the stemming algorithm defined by a snowball script.
    Generated from portuguese.sbl by Snowball 3.2.0 - https://snowballstem.org/
    '''

    g_v = {"a", "e", "i", "o", "u", "á", "â", "é", "ê", "í", "ó", "ô", "ú"}


    def _stem(self):
        v_1 = self.cursor
        try:
            while True:
                v_2 = self.cursor
                try:
                    self.bra = self.cursor
                    among_var = self.find_among(PortugueseStemmer.a_0)
                    self.ket = self.cursor
                    if among_var == 1:
                        self.slice_from("a~")
                    elif among_var == 2:
                        self.slice_from("o~")
                    else:
                        if self.cursor >= self.limit:
                            raise lab1()
                        self.cursor += 1
                    continue
                except lab1: pass
                self.cursor = v_2
                break
        except lab0: pass
        self.cursor = v_1
        try:
            I_pV = self.limit
            I_p1 = self.limit
            I_p2 = self.limit
            v_3 = self.cursor
            try:
                while True:
                    v_4 = self.cursor
                    try:
                        if not self.in_grouping(PortugueseStemmer.g_v):
                            raise lab2()
                        while True:
                            v_5 = self.cursor
                            try:
                                if not self.out_grouping(PortugueseStemmer.g_v):
                                    raise lab3()
                                if not self.go_out_grouping(PortugueseStemmer.g_v):
                                    raise lab3()
                                self.cursor += 1
                                break
                            except lab3: pass
                            self.cursor = v_5
                            if not self.in_grouping(PortugueseStemmer.g_v):
                                raise lab2()
                            if not self.go_in_grouping(PortugueseStemmer.g_v):
                                raise lab2()
                            self.cursor += 1
                            break
                        break
                    except lab2: pass
                    self.cursor = v_4
                    if not self.out_grouping(PortugueseStemmer.g_v):
                        raise lab1()
                    while True:
                        v_6 = self.cursor
                        try:
                            if not self.out_grouping(PortugueseStemmer.g_v):
                                raise lab2()
                            if not self.go_out_grouping(PortugueseStemmer.g_v):
                                raise lab2()
                            self.cursor += 1
                            break
                        except lab2: pass
                        self.cursor = v_6
                        if not self.in_grouping(PortugueseStemmer.g_v):
                            raise lab1()
                        if self.cursor >= self.limit:
                            raise lab1()
                        self.cursor += 1
                        break
                    break
                I_pV = self.cursor
            except lab1: pass
            self.cursor = v_3
            v_7 = self.cursor
            try:
                if not self.go_out_grouping(PortugueseStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                if not self.go_in_grouping(PortugueseStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                I_p1 = self.cursor
                if not self.go_out_grouping(PortugueseStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                if not self.go_in_grouping(PortugueseStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                I_p2 = self.cursor
            except lab1: pass
            self.cursor = v_7
        except lab0: pass
        self.limit_backward = self.cursor
        self.cursor = self.limit
        v_8 = self.limit - self.cursor
        try:
            while True:
                v_9 = self.limit - self.cursor
                try:
                    v_10 = self.limit - self.cursor
                    while True:
                        v_11 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            among_var = self.find_among_b(PortugueseStemmer.a_5)
                            if among_var == 0:
                                raise lab2()
                            self.bra = self.cursor
                            if among_var == 1:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_del()
                            elif among_var == 2:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_from("log")
                            elif among_var == 3:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_from("u")
                            elif among_var == 4:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_from("ente")
                            elif among_var == 5:
                                if I_p1 > self.cursor:
                                    raise lab2()
                                self.slice_del()
                                v_12 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    among_var = self.find_among_b(PortugueseStemmer.a_2)
                                    if among_var == 0:
                                        self.cursor = self.limit - v_12
                                        raise lab3()
                                    self.bra = self.cursor
                                    if I_p2 > self.cursor:
                                        self.cursor = self.limit - v_12
                                        raise lab3()
                                    self.slice_del()
                                    if among_var == 1:
                                        self.ket = self.cursor
                                        if not self.eq_s_b("at"):
                                            self.cursor = self.limit - v_12
                                            raise lab3()
                                        self.bra = self.cursor
                                        if I_p2 > self.cursor:
                                            self.cursor = self.limit - v_12
                                            raise lab3()
                                        self.slice_del()
                                except lab3: pass
                            elif among_var == 6:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_del()
                                v_13 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    if self.find_among_b(PortugueseStemmer.a_3) == 0:
                                        self.cursor = self.limit - v_13
                                        raise lab3()
                                    self.bra = self.cursor
                                    if I_p2 > self.cursor:
                                        self.cursor = self.limit - v_13
                                        raise lab3()
                                    self.slice_del()
                                except lab3: pass
                            elif among_var == 7:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_del()
                                v_14 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    if self.find_among_b(PortugueseStemmer.a_4) == 0:
                                        self.cursor = self.limit - v_14
                                        raise lab3()
                                    self.bra = self.cursor
                                    if I_p2 > self.cursor:
                                        self.cursor = self.limit - v_14
                                        raise lab3()
                                    self.slice_del()
                                except lab3: pass
                            elif among_var == 8:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_del()
                                v_15 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    if not self.eq_s_b("at"):
                                        self.cursor = self.limit - v_15
                                        raise lab3()
                                    self.bra = self.cursor
                                    if I_p2 > self.cursor:
                                        self.cursor = self.limit - v_15
                                        raise lab3()
                                    self.slice_del()
                                except lab3: pass
                            else:
                                if I_pV > self.cursor:
                                    raise lab2()
                                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "e":
                                    raise lab2()
                                self.cursor -= 1
                                self.slice_from("ir")
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_11
                        if self.cursor < I_pV:
                            raise lab1()
                        v_17 = self.limit_backward
                        self.limit_backward = I_pV
                        self.ket = self.cursor
                        if self.find_among_b(PortugueseStemmer.a_6) == 0:
                            self.limit_backward = v_17
                            raise lab1()
                        self.bra = self.cursor
                        self.slice_del()
                        self.limit_backward = v_17
                        break
                    self.cursor = self.limit - v_10
                    v_18 = self.limit - self.cursor
                    try:
                        self.ket = self.cursor
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "i":
                            raise lab2()
                        self.cursor -= 1
                        self.bra = self.cursor
                        v_19 = self.limit - self.cursor
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "c":
                            raise lab2()
                        self.cursor -= 1
                        self.cursor = self.limit - v_19
                        if I_pV > self.cursor:
                            raise lab2()
                        self.slice_del()
                    except lab2: pass
                    self.cursor = self.limit - v_18
                    break
                except lab1: pass
                self.cursor = self.limit - v_9
                self.ket = self.cursor
                if self.find_among_b(PortugueseStemmer.a_7) == 0:
                    raise lab0()
                self.bra = self.cursor
                if I_pV > self.cursor:
                    raise lab0()
                self.slice_del()
                break
        except lab0: pass
        self.cursor = self.limit - v_8
        v_20 = self.limit - self.cursor
        try:
            self.ket = self.cursor
            among_var = self.find_among_b(PortugueseStemmer.a_8)
            if among_var == 0:
                raise lab0()
            self.bra = self.cursor
            if among_var == 1:
                if I_pV > self.cursor:
                    raise lab0()
                self.slice_del()
                self.ket = self.cursor
                while True:
                    v_21 = self.limit - self.cursor
                    try:
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "u":
                            raise lab1()
                        self.cursor -= 1
                        self.bra = self.cursor
                        v_22 = self.limit - self.cursor
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "g":
                            raise lab1()
                        self.cursor -= 1
                        self.cursor = self.limit - v_22
                        break
                    except lab1: pass
                    self.cursor = self.limit - v_21
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "i":
                        raise lab0()
                    self.cursor -= 1
                    self.bra = self.cursor
                    v_23 = self.limit - self.cursor
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "c":
                        raise lab0()
                    self.cursor -= 1
                    self.cursor = self.limit - v_23
                    break
                if I_pV > self.cursor:
                    raise lab0()
                self.slice_del()
            else:
                self.slice_from("c")
        except lab0: pass
        self.cursor = self.limit - v_20
        self.cursor = self.limit_backward
        v_24 = self.cursor
        try:
            while True:
                v_25 = self.cursor
                try:
                    self.bra = self.cursor
                    among_var = self.find_among(PortugueseStemmer.a_1)
                    self.ket = self.cursor
                    if among_var == 1:
                        self.slice_from("ã")
                    elif among_var == 2:
                        self.slice_from("õ")
                    else:
                        if self.cursor >= self.limit:
                            raise lab1()
                        self.cursor += 1
                    continue
                except lab1: pass
                self.cursor = v_25
                break
        except lab0: pass
        self.cursor = v_24
        return True

    a_0 = [
        Among("", -1, 3),
        Among("ã", 0, 1),
        Among("õ", 0, 2)
    ]

    a_1 = [
        Among("", -1, 3),
        Among("a~", 0, 1),
        Among("o~", 0, 2)
    ]

    a_2 = [
        Among("ic", -1, -1),
        Among("ad", -1, -1),
        Among("os", -1, -1),
        Among("iv", -1, 1)
    ]

    a_3 = [
        Among("ante", -1, 1),
        Among("avel", -1, 1),
        Among("ível", -1, 1)
    ]

    a_4 = [
        Among("ic", -1, 1),
        Among("abil", -1, 1),
        Among("iv", -1, 1)
    ]

    a_5 = [
        Among("ica", -1, 1),
        Among("ância", -1, 1),
        Among("ência", -1, 4),
        Among("logia", -1, 2),
        Among("ira", -1, 9),
        Among("adora", -1, 1),
        Among("osa", -1, 1),
        Among("ista", -1, 1),
        Among("iva", -1, 8),
        Among("eza", -1, 1),
        Among("idade", -1, 7),
        Among("ante", -1, 1),
        Among("mente", -1, 6),
        Among("amente", 12, 5),
        Among("ável", -1, 1),
        Among("ível", -1, 1),
        Among("ico", -1, 1),
        Among("ismo", -1, 1),
        Among("oso", -1, 1),
        Among("amento", -1, 1),
        Among("imento", -1, 1),
        Among("ivo", -1, 8),
        Among("aça~o", -1, 1),
        Among("uça~o", -1, 3),
        Among("ador", -1, 1),
        Among("icas", -1, 1),
        Among("ências", -1, 4),
        Among("logias", -1, 2),
        Among("iras", -1, 9),
        Among("adoras", -1, 1),
        Among("osas", -1, 1),
        Among("istas", -1, 1),
        Among("ivas", -1, 8),
        Among("ezas", -1, 1),
        Among("idades", -1, 7),
        Among("adores", -1, 1),
        Among("antes", -1, 1),
        Among("aço~es", -1, 1),
        Among("uço~es", -1, 3),
        Among("icos", -1, 1),
        Among("ismos", -1, 1),
        Among("osos", -1, 1),
        Among("amentos", -1, 1),
        Among("imentos", -1, 1),
        Among("ivos", -1, 8)
    ]

    a_6 = [
        Among("ada", -1, 1),
        Among("ida", -1, 1),
        Among("ia", -1, 1),
        Among("aria", 2, 1),
        Among("eria", 2, 1),
        Among("iria", 2, 1),
        Among("ara", -1, 1),
        Among("era", -1, 1),
        Among("ira", -1, 1),
        Among("ava", -1, 1),
        Among("asse", -1, 1),
        Among("esse", -1, 1),
        Among("isse", -1, 1),
        Among("aste", -1, 1),
        Among("este", -1, 1),
        Among("iste", -1, 1),
        Among("ei", -1, 1),
        Among("arei", 16, 1),
        Among("erei", 16, 1),
        Among("irei", 16, 1),
        Among("am", -1, 1),
        Among("iam", 20, 1),
        Among("ariam", 21, 1),
        Among("eriam", 21, 1),
        Among("iriam", 21, 1),
        Among("aram", 20, 1),
        Among("eram", 20, 1),
        Among("iram", 20, 1),
        Among("avam", 20, 1),
        Among("em", -1, 1),
        Among("arem", 29, 1),
        Among("erem", 29, 1),
        Among("irem", 29, 1),
        Among("assem", 29, 1),
        Among("essem", 29, 1),
        Among("issem", 29, 1),
        Among("ado", -1, 1),
        Among("ido", -1, 1),
        Among("ando", -1, 1),
        Among("endo", -1, 1),
        Among("indo", -1, 1),
        Among("ara~o", -1, 1),
        Among("era~o", -1, 1),
        Among("ira~o", -1, 1),
        Among("ar", -1, 1),
        Among("er", -1, 1),
        Among("ir", -1, 1),
        Among("as", -1, 1),
        Among("adas", 47, 1),
        Among("idas", 47, 1),
        Among("ias", 47, 1),
        Among("arias", 50, 1),
        Among("erias", 50, 1),
        Among("irias", 50, 1),
        Among("aras", 47, 1),
        Among("eras", 47, 1),
        Among("iras", 47, 1),
        Among("avas", 47, 1),
        Among("es", -1, 1),
        Among("ardes", 58, 1),
        Among("erdes", 58, 1),
        Among("irdes", 58, 1),
        Among("ares", 58, 1),
        Among("eres", 58, 1),
        Among("ires", 58, 1),
        Among("asses", 58, 1),
        Among("esses", 58, 1),
        Among("isses", 58, 1),
        Among("astes", 58, 1),
        Among("estes", 58, 1),
        Among("istes", 58, 1),
        Among("is", -1, 1),
        Among("ais", 71, 1),
        Among("eis", 71, 1),
        Among("areis", 73, 1),
        Among("ereis", 73, 1),
        Among("ireis", 73, 1),
        Among("áreis", 73, 1),
        Among("éreis", 73, 1),
        Among("íreis", 73, 1),
        Among("ásseis", 73, 1),
        Among("ésseis", 73, 1),
        Among("ísseis", 73, 1),
        Among("áveis", 73, 1),
        Among("íeis", 73, 1),
        Among("aríeis", 84, 1),
        Among("eríeis", 84, 1),
        Among("iríeis", 84, 1),
        Among("ados", -1, 1),
        Among("idos", -1, 1),
        Among("amos", -1, 1),
        Among("áramos", 90, 1),
        Among("éramos", 90, 1),
        Among("íramos", 90, 1),
        Among("ávamos", 90, 1),
        Among("íamos", 90, 1),
        Among("aríamos", 95, 1),
        Among("eríamos", 95, 1),
        Among("iríamos", 95, 1),
        Among("emos", -1, 1),
        Among("aremos", 99, 1),
        Among("eremos", 99, 1),
        Among("iremos", 99, 1),
        Among("ássemos", 99, 1),
        Among("êssemos", 99, 1),
        Among("íssemos", 99, 1),
        Among("imos", -1, 1),
        Among("armos", -1, 1),
        Among("ermos", -1, 1),
        Among("irmos", -1, 1),
        Among("ámos", -1, 1),
        Among("arás", -1, 1),
        Among("erás", -1, 1),
        Among("irás", -1, 1),
        Among("eu", -1, 1),
        Among("iu", -1, 1),
        Among("ou", -1, 1),
        Among("ará", -1, 1),
        Among("erá", -1, 1),
        Among("irá", -1, 1)
    ]

    a_7 = [
        Among("a", -1, 1),
        Among("i", -1, 1),
        Among("o", -1, 1),
        Among("os", -1, 1),
        Among("á", -1, 1),
        Among("í", -1, 1),
        Among("ó", -1, 1)
    ]

    a_8 = [
        Among("e", -1, 1),
        Among("ç", -1, 2),
        Among("é", -1, 1),
        Among("ê", -1, 1)
    ]


class lab0(BaseException): pass


class lab1(BaseException): pass


class lab2(BaseException): pass


class lab3(BaseException): pass
