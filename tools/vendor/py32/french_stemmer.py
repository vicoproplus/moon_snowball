# Generated from french.sbl by Snowball 3.2.0 - https://snowballstem.org/

from .basestemmer import BaseStemmer
from .among import Among


class FrenchStemmer(BaseStemmer):
    '''
    This class implements the stemming algorithm defined by a snowball script.
    Generated from french.sbl by Snowball 3.2.0 - https://snowballstem.org/
    '''

    g_v = {"a", "e", "i", "o", "u", "y", "à", "â", "è", "é", "ê", "ë", "î", "ï", "ô", "ù", "û"}

    g_oux_ending = {"b", "h", "j", "l", "n", "p"}

    g_elision_char = {"c", "d", "j", "l", "m", "n", "s", "t", "z"}

    g_keep_with_s = {"a", "i", "o", "s", "u", "è"}


    def _stem(self):
        v_1 = self.cursor
        try:
            self.bra = self.cursor
            while True:
                try:
                    if not self.in_grouping(FrenchStemmer.g_elision_char):
                        raise lab1()
                    break
                except lab1: pass
                if not self.eq_s("qu"):
                    raise lab0()
                break
            if self.cursor == self.limit or self.current[self.cursor] != "'":
                raise lab0()
            self.cursor += 1
            self.ket = self.cursor
            if self.cursor >= self.limit:
                raise lab0()
            self.slice_del()
        except lab0: pass
        self.cursor = v_1
        v_2 = self.cursor
        try:
            while True:
                v_3 = self.cursor
                try:
                    while True:
                        v_4 = self.cursor
                        try:
                            while True:
                                v_5 = self.cursor
                                try:
                                    if not self.in_grouping(FrenchStemmer.g_v):
                                        raise lab3()
                                    self.bra = self.cursor
                                    while True:
                                        v_6 = self.cursor
                                        try:
                                            if self.cursor == self.limit or self.current[self.cursor] != "u":
                                                raise lab4()
                                            self.cursor += 1
                                            self.ket = self.cursor
                                            if not self.in_grouping(FrenchStemmer.g_v):
                                                raise lab4()
                                            self.slice_from("U")
                                            break
                                        except lab4: pass
                                        self.cursor = v_6
                                        try:
                                            if self.cursor == self.limit or self.current[self.cursor] != "i":
                                                raise lab4()
                                            self.cursor += 1
                                            self.ket = self.cursor
                                            if not self.in_grouping(FrenchStemmer.g_v):
                                                raise lab4()
                                            self.slice_from("I")
                                            break
                                        except lab4: pass
                                        self.cursor = v_6
                                        if self.cursor == self.limit or self.current[self.cursor] != "y":
                                            raise lab3()
                                        self.cursor += 1
                                        self.ket = self.cursor
                                        self.slice_from("Y")
                                        break
                                    break
                                except lab3: pass
                                self.cursor = v_5
                                try:
                                    self.bra = self.cursor
                                    if self.cursor == self.limit or self.current[self.cursor] != "ë":
                                        raise lab3()
                                    self.cursor += 1
                                    self.ket = self.cursor
                                    self.slice_from("He")
                                    break
                                except lab3: pass
                                self.cursor = v_5
                                try:
                                    self.bra = self.cursor
                                    if self.cursor == self.limit or self.current[self.cursor] != "ï":
                                        raise lab3()
                                    self.cursor += 1
                                    self.ket = self.cursor
                                    self.slice_from("Hi")
                                    break
                                except lab3: pass
                                self.cursor = v_5
                                try:
                                    self.bra = self.cursor
                                    if self.cursor == self.limit or self.current[self.cursor] != "y":
                                        raise lab3()
                                    self.cursor += 1
                                    self.ket = self.cursor
                                    if not self.in_grouping(FrenchStemmer.g_v):
                                        raise lab3()
                                    self.slice_from("Y")
                                    break
                                except lab3: pass
                                self.cursor = v_5
                                if self.cursor == self.limit or self.current[self.cursor] != "q":
                                    raise lab2()
                                self.cursor += 1
                                self.bra = self.cursor
                                if self.cursor == self.limit or self.current[self.cursor] != "u":
                                    raise lab2()
                                self.cursor += 1
                                self.ket = self.cursor
                                self.slice_from("U")
                                break
                            self.cursor = v_4
                            break
                        except lab2: pass
                        self.cursor = v_4
                        if self.cursor >= self.limit:
                            raise lab1()
                        self.cursor += 1
                    continue
                except lab1: pass
                self.cursor = v_3
                break
        except lab0: pass
        self.cursor = v_2
        try:
            I_pV = self.limit
            I_p1 = self.limit
            I_p2 = self.limit
            v_7 = self.cursor
            try:
                while True:
                    v_8 = self.cursor
                    try:
                        if not self.in_grouping(FrenchStemmer.g_v):
                            raise lab2()
                        if not self.in_grouping(FrenchStemmer.g_v):
                            raise lab2()
                        if self.cursor >= self.limit:
                            raise lab2()
                        self.cursor += 1
                        break
                    except lab2: pass
                    self.cursor = v_8
                    try:
                        among_var = self.find_among(FrenchStemmer.a_0)
                        if among_var == 0:
                            raise lab2()
                        if among_var == 1:
                            if not self.in_grouping(FrenchStemmer.g_v):
                                raise lab2()
                        break
                    except lab2: pass
                    self.cursor = v_8
                    if self.cursor >= self.limit:
                        raise lab1()
                    self.cursor += 1
                    if not self.go_out_grouping(FrenchStemmer.g_v):
                        raise lab1()
                    self.cursor += 1
                    break
                I_pV = self.cursor
            except lab1: pass
            self.cursor = v_7
            v_9 = self.cursor
            try:
                if not self.go_out_grouping(FrenchStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                if not self.go_in_grouping(FrenchStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                I_p1 = self.cursor
                if not self.go_out_grouping(FrenchStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                if not self.go_in_grouping(FrenchStemmer.g_v):
                    raise lab1()
                self.cursor += 1
                I_p2 = self.cursor
            except lab1: pass
            self.cursor = v_9
        except lab0: pass
        self.limit_backward = self.cursor
        self.cursor = self.limit
        v_10 = self.limit - self.cursor
        try:
            while True:
                v_11 = self.limit - self.cursor
                try:
                    v_12 = self.limit - self.cursor
                    while True:
                        v_13 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            among_var = self.find_among_b(FrenchStemmer.a_4)
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
                                self.slice_del()
                                v_14 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    if not self.eq_s_b("ic"):
                                        self.cursor = self.limit - v_14
                                        raise lab3()
                                    self.bra = self.cursor
                                    while True:
                                        v_15 = self.limit - self.cursor
                                        try:
                                            if I_p2 > self.cursor:
                                                raise lab4()
                                            self.slice_del()
                                            break
                                        except lab4: pass
                                        self.cursor = self.limit - v_15
                                        self.slice_from("iqU")
                                        break
                                except lab3: pass
                            elif among_var == 3:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_from("log")
                            elif among_var == 4:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_from("u")
                            elif among_var == 5:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_from("ent")
                            elif among_var == 6:
                                if I_pV > self.cursor:
                                    raise lab2()
                                self.slice_del()
                                v_16 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    among_var = self.find_among_b(FrenchStemmer.a_2)
                                    if among_var == 0:
                                        self.cursor = self.limit - v_16
                                        raise lab3()
                                    self.bra = self.cursor
                                    if among_var == 1:
                                        if I_p2 > self.cursor:
                                            self.cursor = self.limit - v_16
                                            raise lab3()
                                        self.slice_del()
                                        self.ket = self.cursor
                                        if not self.eq_s_b("at"):
                                            self.cursor = self.limit - v_16
                                            raise lab3()
                                        self.bra = self.cursor
                                        if I_p2 > self.cursor:
                                            self.cursor = self.limit - v_16
                                            raise lab3()
                                        self.slice_del()
                                    elif among_var == 2:
                                        while True:
                                            v_17 = self.limit - self.cursor
                                            try:
                                                if I_p2 > self.cursor:
                                                    raise lab4()
                                                self.slice_del()
                                                break
                                            except lab4: pass
                                            self.cursor = self.limit - v_17
                                            if I_p1 > self.cursor:
                                                self.cursor = self.limit - v_16
                                                raise lab3()
                                            self.slice_from("eux")
                                            break
                                    elif among_var == 3:
                                        if I_p2 > self.cursor:
                                            self.cursor = self.limit - v_16
                                            raise lab3()
                                        self.slice_del()
                                    else:
                                        if I_pV > self.cursor:
                                            self.cursor = self.limit - v_16
                                            raise lab3()
                                        self.slice_from("i")
                                except lab3: pass
                            elif among_var == 7:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_del()
                                v_18 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    among_var = self.find_among_b(FrenchStemmer.a_3)
                                    if among_var == 0:
                                        self.cursor = self.limit - v_18
                                        raise lab3()
                                    self.bra = self.cursor
                                    if among_var == 1:
                                        while True:
                                            v_19 = self.limit - self.cursor
                                            try:
                                                if I_p2 > self.cursor:
                                                    raise lab4()
                                                self.slice_del()
                                                break
                                            except lab4: pass
                                            self.cursor = self.limit - v_19
                                            self.slice_from("abl")
                                            break
                                    elif among_var == 2:
                                        while True:
                                            v_20 = self.limit - self.cursor
                                            try:
                                                if I_p2 > self.cursor:
                                                    raise lab4()
                                                self.slice_del()
                                                break
                                            except lab4: pass
                                            self.cursor = self.limit - v_20
                                            self.slice_from("iqU")
                                            break
                                    else:
                                        if I_p2 > self.cursor:
                                            self.cursor = self.limit - v_18
                                            raise lab3()
                                        self.slice_del()
                                except lab3: pass
                            elif among_var == 8:
                                if I_p2 > self.cursor:
                                    raise lab2()
                                self.slice_del()
                                v_21 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    if not self.eq_s_b("at"):
                                        self.cursor = self.limit - v_21
                                        raise lab3()
                                    self.bra = self.cursor
                                    if I_p2 > self.cursor:
                                        self.cursor = self.limit - v_21
                                        raise lab3()
                                    self.slice_del()
                                    self.ket = self.cursor
                                    if not self.eq_s_b("ic"):
                                        self.cursor = self.limit - v_21
                                        raise lab3()
                                    self.bra = self.cursor
                                    while True:
                                        v_22 = self.limit - self.cursor
                                        try:
                                            if I_p2 > self.cursor:
                                                raise lab4()
                                            self.slice_del()
                                            break
                                        except lab4: pass
                                        self.cursor = self.limit - v_22
                                        self.slice_from("iqU")
                                        break
                                except lab3: pass
                            elif among_var == 9:
                                self.slice_from("eau")
                            elif among_var == 10:
                                if I_p1 > self.cursor:
                                    raise lab2()
                                self.slice_from("al")
                            elif among_var == 11:
                                if not self.in_grouping_b(FrenchStemmer.g_oux_ending):
                                    raise lab2()
                                self.slice_from("ou")
                            elif among_var == 12:
                                while True:
                                    v_23 = self.limit - self.cursor
                                    try:
                                        if I_p2 > self.cursor:
                                            raise lab3()
                                        self.slice_del()
                                        break
                                    except lab3: pass
                                    self.cursor = self.limit - v_23
                                    if I_p1 > self.cursor:
                                        raise lab2()
                                    self.slice_from("eux")
                                    break
                            elif among_var == 13:
                                if I_p1 > self.cursor:
                                    raise lab2()
                                if not self.out_grouping_b(FrenchStemmer.g_v):
                                    raise lab2()
                                self.slice_del()
                            elif among_var == 14:
                                if I_pV > self.cursor:
                                    raise lab2()
                                self.slice_from("ant")
                                raise lab2()
                            elif among_var == 15:
                                if I_pV > self.cursor:
                                    raise lab2()
                                self.slice_from("ent")
                                raise lab2()
                            else:
                                v_24 = self.limit - self.cursor
                                if not self.in_grouping_b(FrenchStemmer.g_v):
                                    raise lab2()
                                if I_pV > self.cursor:
                                    raise lab2()
                                self.cursor = self.limit - v_24
                                self.slice_del()
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_13
                        try:
                            if self.cursor < I_pV:
                                raise lab2()
                            v_26 = self.limit_backward
                            self.limit_backward = I_pV
                            self.ket = self.cursor
                            if self.find_among_b(FrenchStemmer.a_5) == 0:
                                self.limit_backward = v_26
                                raise lab2()
                            self.bra = self.cursor
                            try:
                                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "H":
                                    raise lab3()
                                self.cursor -= 1
                                self.limit_backward = v_26
                                raise lab2()
                            except lab3: pass
                            if not self.out_grouping_b(FrenchStemmer.g_v):
                                self.limit_backward = v_26
                                raise lab2()
                            self.slice_del()
                            self.limit_backward = v_26
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_13
                        if self.cursor < I_pV:
                            raise lab1()
                        v_28 = self.limit_backward
                        self.limit_backward = I_pV
                        self.ket = self.cursor
                        among_var = self.find_among_b(FrenchStemmer.a_7)
                        if among_var == 0:
                            self.limit_backward = v_28
                            raise lab1()
                        self.bra = self.cursor
                        self.limit_backward = v_28
                        if among_var == 1:
                            if I_p2 > self.cursor:
                                raise lab1()
                            self.slice_del()
                        elif among_var == 2:
                            self.slice_del()
                        elif among_var == 3:
                            v_29 = self.limit - self.cursor
                            try:
                                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "e":
                                    self.cursor = self.limit - v_29
                                    raise lab2()
                                self.cursor -= 1
                                if I_pV > self.cursor:
                                    self.cursor = self.limit - v_29
                                    raise lab2()
                                self.bra = self.cursor
                            except lab2: pass
                            self.slice_del()
                        else:
                            v_30 = self.limit - self.cursor
                            try:
                                among_var = self.find_among_b(FrenchStemmer.a_6)
                                if among_var == 0:
                                    raise lab2()
                                if among_var == 1:
                                    if self.cursor <= self.limit_backward:
                                        raise lab2()
                                    self.cursor -= 1
                                    if self.cursor > self.limit_backward:
                                        raise lab2()
                                raise lab1()
                            except lab2: pass
                            self.cursor = self.limit - v_30
                            self.slice_del()
                        break
                    self.cursor = self.limit - v_12
                    v_31 = self.limit - self.cursor
                    try:
                        self.ket = self.cursor
                        while True:
                            v_32 = self.limit - self.cursor
                            try:
                                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "Y":
                                    raise lab3()
                                self.cursor -= 1
                                self.bra = self.cursor
                                self.slice_from("i")
                                break
                            except lab3: pass
                            self.cursor = self.limit - v_32
                            if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "ç":
                                self.cursor = self.limit - v_31
                                raise lab2()
                            self.cursor -= 1
                            self.bra = self.cursor
                            self.slice_from("c")
                            break
                    except lab2: pass
                    break
                except lab1: pass
                self.cursor = self.limit - v_11
                v_33 = self.limit - self.cursor
                try:
                    self.ket = self.cursor
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "s":
                        self.cursor = self.limit - v_33
                        raise lab1()
                    self.cursor -= 1
                    self.bra = self.cursor
                    v_34 = self.limit - self.cursor
                    while True:
                        try:
                            if not self.eq_s_b("Hi"):
                                raise lab2()
                            break
                        except lab2: pass
                        if not self.out_grouping_b(FrenchStemmer.g_keep_with_s):
                            self.cursor = self.limit - v_33
                            raise lab1()
                        break
                    self.cursor = self.limit - v_34
                    self.slice_del()
                except lab1: pass
                if self.cursor < I_pV:
                    raise lab0()
                v_36 = self.limit_backward
                self.limit_backward = I_pV
                self.ket = self.cursor
                among_var = self.find_among_b(FrenchStemmer.a_8)
                if among_var == 0:
                    self.limit_backward = v_36
                    raise lab0()
                self.bra = self.cursor
                if among_var == 1:
                    if I_p2 > self.cursor:
                        self.limit_backward = v_36
                        raise lab0()
                    while True:
                        try:
                            if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "s":
                                raise lab1()
                            self.cursor -= 1
                            break
                        except lab1: pass
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "t":
                            self.limit_backward = v_36
                            raise lab0()
                        self.cursor -= 1
                        break
                    self.slice_del()
                elif among_var == 2:
                    self.slice_from("i")
                else:
                    self.slice_del()
                self.limit_backward = v_36
                break
        except lab0: pass
        self.cursor = self.limit - v_10
        v_37 = self.limit - self.cursor
        try:
            v_38 = self.limit - self.cursor
            if self.find_among_b(FrenchStemmer.a_9) == 0:
                raise lab0()
            self.cursor = self.limit - v_38
            self.ket = self.cursor
            if self.cursor <= self.limit_backward:
                raise lab0()
            self.cursor -= 1
            self.bra = self.cursor
            self.slice_del()
        except lab0: pass
        self.cursor = self.limit - v_37
        v_39 = self.limit - self.cursor
        try:
            v_40 = 1
            while True:
                try:
                    if not self.out_grouping_b(FrenchStemmer.g_v):
                        raise lab1()
                    v_40 -= 1
                    continue
                except lab1: pass
                break
            if v_40 > 0:
                raise lab0()
            self.ket = self.cursor
            while True:
                try:
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "é":
                        raise lab1()
                    self.cursor -= 1
                    break
                except lab1: pass
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "è":
                    raise lab0()
                self.cursor -= 1
                break
            self.bra = self.cursor
            self.slice_from("e")
        except lab0: pass
        self.cursor = self.limit - v_39
        self.cursor = self.limit_backward
        v_41 = self.cursor
        try:
            while True:
                v_42 = self.cursor
                try:
                    self.bra = self.cursor
                    among_var = self.find_among(FrenchStemmer.a_1)
                    self.ket = self.cursor
                    if among_var == 1:
                        self.slice_from("i")
                    elif among_var == 2:
                        self.slice_from("u")
                    elif among_var == 3:
                        self.slice_from("y")
                    elif among_var == 4:
                        self.slice_from("ë")
                    elif among_var == 5:
                        self.slice_from("ï")
                    elif among_var == 6:
                        self.slice_del()
                    else:
                        if self.cursor >= self.limit:
                            raise lab1()
                        self.cursor += 1
                    continue
                except lab1: pass
                self.cursor = v_42
                break
        except lab0: pass
        self.cursor = v_41
        return True

    a_0 = [
        Among("col", -1, -1),
        Among("ni", -1, 1),
        Among("par", -1, -1),
        Among("tap", -1, -1)
    ]

    a_1 = [
        Among("", -1, 7),
        Among("H", 0, 6),
        Among("He", 1, 4),
        Among("Hi", 1, 5),
        Among("I", 0, 1),
        Among("U", 0, 2),
        Among("Y", 0, 3)
    ]

    a_2 = [
        Among("iqU", -1, 3),
        Among("abl", -1, 3),
        Among("Ièr", -1, 4),
        Among("ièr", -1, 4),
        Among("eus", -1, 2),
        Among("iv", -1, 1)
    ]

    a_3 = [
        Among("ic", -1, 2),
        Among("abil", -1, 1),
        Among("iv", -1, 3)
    ]

    a_4 = [
        Among("iqUe", -1, 1),
        Among("atrice", -1, 2),
        Among("ance", -1, 1),
        Among("ence", -1, 5),
        Among("logie", -1, 3),
        Among("able", -1, 1),
        Among("isme", -1, 1),
        Among("euse", -1, 12),
        Among("iste", -1, 1),
        Among("ive", -1, 8),
        Among("if", -1, 8),
        Among("usion", -1, 4),
        Among("ation", -1, 2),
        Among("ution", -1, 4),
        Among("ateur", -1, 2),
        Among("iqUes", -1, 1),
        Among("atrices", -1, 2),
        Among("ances", -1, 1),
        Among("ences", -1, 5),
        Among("logies", -1, 3),
        Among("ables", -1, 1),
        Among("ismes", -1, 1),
        Among("euses", -1, 12),
        Among("istes", -1, 1),
        Among("ives", -1, 8),
        Among("ifs", -1, 8),
        Among("usions", -1, 4),
        Among("ations", -1, 2),
        Among("utions", -1, 4),
        Among("ateurs", -1, 2),
        Among("ments", -1, 16),
        Among("ements", 30, 6),
        Among("issements", 31, 13),
        Among("ités", -1, 7),
        Among("ment", -1, 16),
        Among("ement", 34, 6),
        Among("issement", 35, 13),
        Among("amment", 34, 14),
        Among("emment", 34, 15),
        Among("aux", -1, 10),
        Among("eaux", 39, 9),
        Among("eux", -1, 1),
        Among("oux", -1, 11),
        Among("ité", -1, 7)
    ]

    a_5 = [
        Among("ira", -1, 1),
        Among("ie", -1, 1),
        Among("isse", -1, 1),
        Among("issante", -1, 1),
        Among("i", -1, 1),
        Among("irai", 4, 1),
        Among("ir", -1, 1),
        Among("iras", -1, 1),
        Among("ies", -1, 1),
        Among("îmes", -1, 1),
        Among("isses", -1, 1),
        Among("issantes", -1, 1),
        Among("îtes", -1, 1),
        Among("is", -1, 1),
        Among("irais", 13, 1),
        Among("issais", 13, 1),
        Among("irions", -1, 1),
        Among("issions", -1, 1),
        Among("irons", -1, 1),
        Among("issons", -1, 1),
        Among("issants", -1, 1),
        Among("it", -1, 1),
        Among("irait", 21, 1),
        Among("issait", 21, 1),
        Among("issant", -1, 1),
        Among("iraIent", -1, 1),
        Among("issaIent", -1, 1),
        Among("irent", -1, 1),
        Among("issent", -1, 1),
        Among("iront", -1, 1),
        Among("ît", -1, 1),
        Among("iriez", -1, 1),
        Among("issiez", -1, 1),
        Among("irez", -1, 1),
        Among("issez", -1, 1)
    ]

    a_6 = [
        Among("al", -1, 1),
        Among("épl", -1, -1),
        Among("auv", -1, -1)
    ]

    a_7 = [
        Among("a", -1, 3),
        Among("era", 0, 2),
        Among("aise", -1, 4),
        Among("asse", -1, 3),
        Among("ante", -1, 3),
        Among("ée", -1, 2),
        Among("ai", -1, 3),
        Among("erai", 6, 2),
        Among("er", -1, 2),
        Among("as", -1, 3),
        Among("eras", 9, 2),
        Among("âmes", -1, 3),
        Among("aises", -1, 4),
        Among("asses", -1, 3),
        Among("antes", -1, 3),
        Among("âtes", -1, 3),
        Among("ées", -1, 2),
        Among("ais", -1, 4),
        Among("eais", 17, 2),
        Among("erais", 17, 2),
        Among("ions", -1, 1),
        Among("erions", 20, 2),
        Among("assions", 20, 3),
        Among("erons", -1, 2),
        Among("ants", -1, 3),
        Among("és", -1, 2),
        Among("ait", -1, 3),
        Among("erait", 26, 2),
        Among("ant", -1, 3),
        Among("aIent", -1, 3),
        Among("eraIent", 29, 2),
        Among("èrent", -1, 2),
        Among("assent", -1, 3),
        Among("eront", -1, 2),
        Among("ât", -1, 3),
        Among("ez", -1, 2),
        Among("iez", 35, 2),
        Among("eriez", 36, 2),
        Among("assiez", 36, 3),
        Among("erez", 35, 2),
        Among("é", -1, 2)
    ]

    a_8 = [
        Among("e", -1, 3),
        Among("Ière", 0, 2),
        Among("ière", 0, 2),
        Among("ion", -1, 1),
        Among("Ier", -1, 2),
        Among("ier", -1, 2)
    ]

    a_9 = [
        Among("ell", -1, -1),
        Among("eill", -1, -1),
        Among("enn", -1, -1),
        Among("onn", -1, -1),
        Among("ett", -1, -1)
    ]


class lab0(BaseException): pass


class lab1(BaseException): pass


class lab2(BaseException): pass


class lab3(BaseException): pass


class lab4(BaseException): pass
