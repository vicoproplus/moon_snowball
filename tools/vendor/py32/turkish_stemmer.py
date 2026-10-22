# Generated from turkish.sbl by Snowball 3.2.0 - https://snowballstem.org/

from .basestemmer import BaseStemmer
from .among import Among


class TurkishStemmer(BaseStemmer):
    '''
    This class implements the stemming algorithm defined by a snowball script.
    Generated from turkish.sbl by Snowball 3.2.0 - https://snowballstem.org/
    '''

    g_vowel = {"a", "e", "i", "o", "u", "ö", "ü", "ı"}

    g_U = {"i", "u", "ü", "ı"}

    g_vowel1 = {"a", "o", "u", "ı"}

    g_vowel2 = {"e", "i", "ö", "ü"}

    g_vowel3 = "aı"
    g_vowel4 = "ei"
    g_vowel5 = "ou"
    g_vowel6 = "öü"

    def __r_check_vowel_harmony(self):
        v_1 = self.limit - self.cursor
        if not self.go_out_grouping_b(TurkishStemmer.g_vowel):
            return False
        while True:
            v_2 = self.limit - self.cursor
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "a":
                    raise lab0()
                self.cursor -= 1
                if not self.go_out_grouping_b(TurkishStemmer.g_vowel1):
                    raise lab0()
                break
            except lab0: pass
            self.cursor = self.limit - v_2
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "e":
                    raise lab0()
                self.cursor -= 1
                if not self.go_out_grouping_b(TurkishStemmer.g_vowel2):
                    raise lab0()
                break
            except lab0: pass
            self.cursor = self.limit - v_2
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "ı":
                    raise lab0()
                self.cursor -= 1
                if not self.go_out_grouping_b(TurkishStemmer.g_vowel3):
                    raise lab0()
                break
            except lab0: pass
            self.cursor = self.limit - v_2
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "i":
                    raise lab0()
                self.cursor -= 1
                if not self.go_out_grouping_b(TurkishStemmer.g_vowel4):
                    raise lab0()
                break
            except lab0: pass
            self.cursor = self.limit - v_2
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "o":
                    raise lab0()
                self.cursor -= 1
                if not self.go_out_grouping_b(TurkishStemmer.g_vowel5):
                    raise lab0()
                break
            except lab0: pass
            self.cursor = self.limit - v_2
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "ö":
                    raise lab0()
                self.cursor -= 1
                if not self.go_out_grouping_b(TurkishStemmer.g_vowel6):
                    raise lab0()
                break
            except lab0: pass
            self.cursor = self.limit - v_2
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "u":
                    raise lab0()
                self.cursor -= 1
                if not self.go_out_grouping_b(TurkishStemmer.g_vowel5):
                    raise lab0()
                break
            except lab0: pass
            self.cursor = self.limit - v_2
            if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "ü":
                return False
            self.cursor -= 1
            if not self.go_out_grouping_b(TurkishStemmer.g_vowel6):
                return False
            break
        self.cursor = self.limit - v_1
        return True

    def __r_mark_suffix_with_optional_n_consonant(self):
        while True:
            v_1 = self.limit - self.cursor
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "n":
                    raise lab0()
                self.cursor -= 1
                v_2 = self.limit - self.cursor
                if not self.in_grouping_b(TurkishStemmer.g_vowel):
                    raise lab0()
                self.cursor = self.limit - v_2
                break
            except lab0: pass
            self.cursor = self.limit - v_1
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "n":
                    raise lab0()
                self.cursor -= 1
                return False
            except lab0: pass
            v_3 = self.limit - self.cursor
            if self.cursor <= self.limit_backward:
                return False
            self.cursor -= 1
            if not self.in_grouping_b(TurkishStemmer.g_vowel):
                return False
            self.cursor = self.limit - v_3
            break
        return True

    def __r_mark_suffix_with_optional_y_consonant(self):
        while True:
            v_1 = self.limit - self.cursor
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "y":
                    raise lab0()
                self.cursor -= 1
                v_2 = self.limit - self.cursor
                if not self.in_grouping_b(TurkishStemmer.g_vowel):
                    raise lab0()
                self.cursor = self.limit - v_2
                break
            except lab0: pass
            self.cursor = self.limit - v_1
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "y":
                    raise lab0()
                self.cursor -= 1
                return False
            except lab0: pass
            v_3 = self.limit - self.cursor
            if self.cursor <= self.limit_backward:
                return False
            self.cursor -= 1
            if not self.in_grouping_b(TurkishStemmer.g_vowel):
                return False
            self.cursor = self.limit - v_3
            break
        return True

    def __r_mark_possessives(self):
        if self.find_among_b(TurkishStemmer.a_0) == 0:
            return False
        while True:
            v_1 = self.limit - self.cursor
            try:
                if not self.in_grouping_b(TurkishStemmer.g_U):
                    raise lab0()
                v_2 = self.limit - self.cursor
                if not self.out_grouping_b(TurkishStemmer.g_vowel):
                    raise lab0()
                self.cursor = self.limit - v_2
                break
            except lab0: pass
            self.cursor = self.limit - v_1
            try:
                if not self.in_grouping_b(TurkishStemmer.g_U):
                    raise lab0()
                return False
            except lab0: pass
            v_3 = self.limit - self.cursor
            if self.cursor <= self.limit_backward:
                return False
            self.cursor -= 1
            if not self.out_grouping_b(TurkishStemmer.g_vowel):
                return False
            self.cursor = self.limit - v_3
            break
        return True

    def __r_mark_sU(self):
        if not self.__r_check_vowel_harmony():
            return False
        if not self.in_grouping_b(TurkishStemmer.g_U):
            return False
        while True:
            v_1 = self.limit - self.cursor
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "s":
                    raise lab0()
                self.cursor -= 1
                v_2 = self.limit - self.cursor
                if not self.in_grouping_b(TurkishStemmer.g_vowel):
                    raise lab0()
                self.cursor = self.limit - v_2
                break
            except lab0: pass
            self.cursor = self.limit - v_1
            try:
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "s":
                    raise lab0()
                self.cursor -= 1
                return False
            except lab0: pass
            v_3 = self.limit - self.cursor
            if self.cursor <= self.limit_backward:
                return False
            self.cursor -= 1
            if not self.in_grouping_b(TurkishStemmer.g_vowel):
                return False
            self.cursor = self.limit - v_3
            break
        return True

    def __r_mark_lArI(self):
        return self.find_among_b(TurkishStemmer.a_1) != 0

    def __r_mark_nUn(self):
        if not self.__r_check_vowel_harmony():
            return False
        if self.find_among_b(TurkishStemmer.a_3) == 0:
            return False
        return self.__r_mark_suffix_with_optional_n_consonant()

    def __r_mark_DA(self):
        if not self.__r_check_vowel_harmony():
            return False
        return self.find_among_b(TurkishStemmer.a_6) != 0

    def __r_mark_ndA(self):
        if not self.__r_check_vowel_harmony():
            return False
        return self.find_among_b(TurkishStemmer.a_7) != 0

    def __r_mark_yUm(self):
        if not self.__r_check_vowel_harmony():
            return False
        if self.find_among_b(TurkishStemmer.a_12) == 0:
            return False
        return self.__r_mark_suffix_with_optional_y_consonant()

    def __r_mark_sUn(self):
        if not self.__r_check_vowel_harmony():
            return False
        return self.find_among_b(TurkishStemmer.a_13) != 0

    def __r_mark_yUz(self):
        if not self.__r_check_vowel_harmony():
            return False
        if self.find_among_b(TurkishStemmer.a_14) == 0:
            return False
        return self.__r_mark_suffix_with_optional_y_consonant()

    def __r_mark_sUnUz(self):
        return self.find_among_b(TurkishStemmer.a_15) != 0

    def __r_mark_lAr(self):
        if not self.__r_check_vowel_harmony():
            return False
        return self.find_among_b(TurkishStemmer.a_16) != 0

    def __r_mark_DUr(self):
        if not self.__r_check_vowel_harmony():
            return False
        return self.find_among_b(TurkishStemmer.a_18) != 0

    def __r_mark_yDU(self):
        if not self.__r_check_vowel_harmony():
            return False
        if self.find_among_b(TurkishStemmer.a_20) == 0:
            return False
        return self.__r_mark_suffix_with_optional_y_consonant()

    def __r_mark_ysA(self):
        if self.find_among_b(TurkishStemmer.a_21) == 0:
            return False
        return self.__r_mark_suffix_with_optional_y_consonant()

    def __r_mark_ymUs_(self):
        if not self.__r_check_vowel_harmony():
            return False
        if self.find_among_b(TurkishStemmer.a_22) == 0:
            return False
        return self.__r_mark_suffix_with_optional_y_consonant()

    def __r_stem_suffix_chain_before_ki(self):
        self.ket = self.cursor
        if not self.eq_s_b("ki"):
            return False
        while True:
            v_1 = self.limit - self.cursor
            try:
                if not self.__r_mark_DA():
                    raise lab0()
                self.bra = self.cursor
                self.slice_del()
                v_2 = self.limit - self.cursor
                try:
                    self.ket = self.cursor
                    while True:
                        v_3 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_lAr():
                                raise lab2()
                            self.bra = self.cursor
                            self.slice_del()
                            v_4 = self.limit - self.cursor
                            try:
                                if not self.__r_stem_suffix_chain_before_ki():
                                    self.cursor = self.limit - v_4
                                    raise lab3()
                            except lab3: pass
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_3
                        if not self.__r_mark_possessives():
                            self.cursor = self.limit - v_2
                            raise lab1()
                        self.bra = self.cursor
                        self.slice_del()
                        v_5 = self.limit - self.cursor
                        try:
                            self.ket = self.cursor
                            if not self.__r_mark_lAr():
                                self.cursor = self.limit - v_5
                                raise lab2()
                            self.bra = self.cursor
                            self.slice_del()
                            if not self.__r_stem_suffix_chain_before_ki():
                                self.cursor = self.limit - v_5
                                raise lab2()
                        except lab2: pass
                        break
                except lab1: pass
                break
            except lab0: pass
            self.cursor = self.limit - v_1
            try:
                if not self.__r_mark_nUn():
                    raise lab0()
                self.bra = self.cursor
                self.slice_del()
                v_6 = self.limit - self.cursor
                try:
                    self.ket = self.cursor
                    while True:
                        v_7 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_lArI():
                                raise lab2()
                            self.bra = self.cursor
                            self.slice_del()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_7
                        try:
                            self.ket = self.cursor
                            while True:
                                v_8 = self.limit - self.cursor
                                try:
                                    if not self.__r_mark_possessives():
                                        raise lab3()
                                    break
                                except lab3: pass
                                self.cursor = self.limit - v_8
                                if not self.__r_mark_sU():
                                    raise lab2()
                                break
                            self.bra = self.cursor
                            self.slice_del()
                            v_9 = self.limit - self.cursor
                            try:
                                self.ket = self.cursor
                                if not self.__r_mark_lAr():
                                    self.cursor = self.limit - v_9
                                    raise lab3()
                                self.bra = self.cursor
                                self.slice_del()
                                if not self.__r_stem_suffix_chain_before_ki():
                                    self.cursor = self.limit - v_9
                                    raise lab3()
                            except lab3: pass
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_7
                        if not self.__r_stem_suffix_chain_before_ki():
                            self.cursor = self.limit - v_6
                            raise lab1()
                        break
                except lab1: pass
                break
            except lab0: pass
            self.cursor = self.limit - v_1
            if not self.__r_mark_ndA():
                return False
            while True:
                v_10 = self.limit - self.cursor
                try:
                    if not self.__r_mark_lArI():
                        raise lab0()
                    self.bra = self.cursor
                    self.slice_del()
                    break
                except lab0: pass
                self.cursor = self.limit - v_10
                try:
                    if not self.__r_mark_sU():
                        raise lab0()
                    self.bra = self.cursor
                    self.slice_del()
                    v_11 = self.limit - self.cursor
                    try:
                        self.ket = self.cursor
                        if not self.__r_mark_lAr():
                            self.cursor = self.limit - v_11
                            raise lab1()
                        self.bra = self.cursor
                        self.slice_del()
                        if not self.__r_stem_suffix_chain_before_ki():
                            self.cursor = self.limit - v_11
                            raise lab1()
                    except lab1: pass
                    break
                except lab0: pass
                self.cursor = self.limit - v_10
                if not self.__r_stem_suffix_chain_before_ki():
                    return False
                break
            break
        return True

    def _stem(self):
        try:
            v_1 = self.cursor
            try:
                self.bra = self.cursor
                while True:
                    v_2 = self.cursor
                    try:
                        try:
                            if self.cursor == self.limit or self.current[self.cursor] != "'":
                                raise lab3()
                            self.cursor += 1
                            raise lab2()
                        except lab3: pass
                        self.cursor = v_2
                        break
                    except lab2: pass
                    self.cursor = v_2
                    if self.cursor >= self.limit:
                        raise lab1()
                    self.cursor += 1
                self.ket = self.cursor
                self.slice_del()
            except lab1: pass
            self.cursor = v_1
            v_3 = self.cursor
            try:
                if self.cursor + 2 > self.limit:
                    raise lab1()
                self.cursor += 2
                while True:
                    v_4 = self.cursor
                    try:
                        if self.cursor == self.limit or self.current[self.cursor] != "'":
                            raise lab2()
                        self.cursor += 1
                        self.cursor = v_4
                        break
                    except lab2: pass
                    self.cursor = v_4
                    if self.cursor >= self.limit:
                        raise lab1()
                    self.cursor += 1
                self.bra = self.cursor
                self.cursor = self.limit
                self.ket = self.cursor
                self.slice_del()
            except lab1: pass
            self.cursor = v_3
        except lab0: pass
        v_5 = self.cursor
        for _ in 0, 0:
            if not self.go_out_grouping(TurkishStemmer.g_vowel):
                return False
            self.cursor += 1
        self.cursor = v_5
        self.limit_backward = self.cursor
        self.cursor = self.limit
        v_6 = self.limit - self.cursor
        try:
            self.ket = self.cursor
            B_continue_stemming_noun_suffixes = True
            while True:
                v_7 = self.limit - self.cursor
                try:
                    while True:
                        v_8 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_ymUs_():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_8
                        try:
                            if not self.__r_mark_yDU():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_8
                        try:
                            if not self.__r_mark_ysA():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_8
                        if not self.eq_s_b("ken"):
                            raise lab1()
                        if not self.__r_mark_suffix_with_optional_y_consonant():
                            raise lab1()
                        break
                    break
                except lab1: pass
                self.cursor = self.limit - v_7
                try:
                    if self.find_among_b(TurkishStemmer.a_19) == 0:
                        raise lab1()
                    while True:
                        v_9 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_sUnUz():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_9
                        try:
                            if not self.__r_mark_lAr():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_9
                        try:
                            if not self.__r_mark_yUm():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_9
                        try:
                            if not self.__r_mark_sUn():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_9
                        try:
                            if not self.__r_mark_yUz():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_9
                        break
                    if not self.__r_mark_ymUs_():
                        raise lab1()
                    break
                except lab1: pass
                self.cursor = self.limit - v_7
                try:
                    if not self.__r_mark_lAr():
                        raise lab1()
                    self.bra = self.cursor
                    self.slice_del()
                    v_10 = self.limit - self.cursor
                    try:
                        self.ket = self.cursor
                        while True:
                            v_11 = self.limit - self.cursor
                            try:
                                if not self.__r_mark_DUr():
                                    raise lab3()
                                break
                            except lab3: pass
                            self.cursor = self.limit - v_11
                            try:
                                if not self.__r_mark_yDU():
                                    raise lab3()
                                break
                            except lab3: pass
                            self.cursor = self.limit - v_11
                            try:
                                if not self.__r_mark_ysA():
                                    raise lab3()
                                break
                            except lab3: pass
                            self.cursor = self.limit - v_11
                            if not self.__r_mark_ymUs_():
                                self.cursor = self.limit - v_10
                                raise lab2()
                            break
                    except lab2: pass
                    B_continue_stemming_noun_suffixes = False
                    break
                except lab1: pass
                self.cursor = self.limit - v_7
                try:
                    if not self.__r_check_vowel_harmony():
                        raise lab1()
                    if self.find_among_b(TurkishStemmer.a_17) == 0:
                        raise lab1()
                    while True:
                        v_12 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_yDU():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_12
                        if not self.__r_mark_ysA():
                            raise lab1()
                        break
                    break
                except lab1: pass
                self.cursor = self.limit - v_7
                try:
                    while True:
                        v_13 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_sUnUz():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_13
                        try:
                            if not self.__r_mark_yUz():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_13
                        try:
                            if not self.__r_mark_sUn():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_13
                        if not self.__r_mark_yUm():
                            raise lab1()
                        break
                    self.bra = self.cursor
                    self.slice_del()
                    v_14 = self.limit - self.cursor
                    try:
                        self.ket = self.cursor
                        if not self.__r_mark_ymUs_():
                            self.cursor = self.limit - v_14
                            raise lab2()
                    except lab2: pass
                    break
                except lab1: pass
                self.cursor = self.limit - v_7
                if not self.__r_mark_DUr():
                    raise lab0()
                self.bra = self.cursor
                self.slice_del()
                v_15 = self.limit - self.cursor
                try:
                    self.ket = self.cursor
                    while True:
                        v_16 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_sUnUz():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_16
                        try:
                            if not self.__r_mark_lAr():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_16
                        try:
                            if not self.__r_mark_yUm():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_16
                        try:
                            if not self.__r_mark_sUn():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_16
                        try:
                            if not self.__r_mark_yUz():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_16
                        break
                    if not self.__r_mark_ymUs_():
                        self.cursor = self.limit - v_15
                        raise lab1()
                except lab1: pass
                break
            self.bra = self.cursor
            self.slice_del()
        except lab0: pass
        self.cursor = self.limit - v_6
        if not B_continue_stemming_noun_suffixes:
            return False
        v_17 = self.limit - self.cursor
        try:
            while True:
                v_18 = self.limit - self.cursor
                try:
                    self.ket = self.cursor
                    if not self.__r_mark_lAr():
                        raise lab1()
                    self.bra = self.cursor
                    self.slice_del()
                    v_19 = self.limit - self.cursor
                    try:
                        if not self.__r_stem_suffix_chain_before_ki():
                            self.cursor = self.limit - v_19
                            raise lab2()
                    except lab2: pass
                    break
                except lab1: pass
                self.cursor = self.limit - v_18
                try:
                    self.ket = self.cursor
                    if not self.__r_check_vowel_harmony():
                        raise lab1()
                    if self.find_among_b(TurkishStemmer.a_11) == 0:
                        raise lab1()
                    if not self.__r_mark_suffix_with_optional_n_consonant():
                        raise lab1()
                    self.bra = self.cursor
                    self.slice_del()
                    v_20 = self.limit - self.cursor
                    try:
                        while True:
                            v_21 = self.limit - self.cursor
                            try:
                                self.ket = self.cursor
                                if not self.__r_mark_lArI():
                                    raise lab3()
                                self.bra = self.cursor
                                self.slice_del()
                                break
                            except lab3: pass
                            self.cursor = self.limit - v_21
                            try:
                                self.ket = self.cursor
                                while True:
                                    v_22 = self.limit - self.cursor
                                    try:
                                        if not self.__r_mark_possessives():
                                            raise lab4()
                                        break
                                    except lab4: pass
                                    self.cursor = self.limit - v_22
                                    if not self.__r_mark_sU():
                                        raise lab3()
                                    break
                                self.bra = self.cursor
                                self.slice_del()
                                v_23 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    if not self.__r_mark_lAr():
                                        self.cursor = self.limit - v_23
                                        raise lab4()
                                    self.bra = self.cursor
                                    self.slice_del()
                                    if not self.__r_stem_suffix_chain_before_ki():
                                        self.cursor = self.limit - v_23
                                        raise lab4()
                                except lab4: pass
                                break
                            except lab3: pass
                            self.cursor = self.limit - v_21
                            self.ket = self.cursor
                            if not self.__r_mark_lAr():
                                self.cursor = self.limit - v_20
                                raise lab2()
                            self.bra = self.cursor
                            self.slice_del()
                            if not self.__r_stem_suffix_chain_before_ki():
                                self.cursor = self.limit - v_20
                                raise lab2()
                            break
                    except lab2: pass
                    break
                except lab1: pass
                self.cursor = self.limit - v_18
                try:
                    self.ket = self.cursor
                    while True:
                        v_24 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_ndA():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_24
                        if not self.__r_check_vowel_harmony():
                            raise lab1()
                        if self.find_among_b(TurkishStemmer.a_5) == 0:
                            raise lab1()
                        break
                    while True:
                        v_25 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_lArI():
                                raise lab2()
                            self.bra = self.cursor
                            self.slice_del()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_25
                        try:
                            if not self.__r_mark_sU():
                                raise lab2()
                            self.bra = self.cursor
                            self.slice_del()
                            v_26 = self.limit - self.cursor
                            try:
                                self.ket = self.cursor
                                if not self.__r_mark_lAr():
                                    self.cursor = self.limit - v_26
                                    raise lab3()
                                self.bra = self.cursor
                                self.slice_del()
                                if not self.__r_stem_suffix_chain_before_ki():
                                    self.cursor = self.limit - v_26
                                    raise lab3()
                            except lab3: pass
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_25
                        if not self.__r_stem_suffix_chain_before_ki():
                            raise lab1()
                        break
                    break
                except lab1: pass
                self.cursor = self.limit - v_18
                try:
                    self.ket = self.cursor
                    while True:
                        v_27 = self.limit - self.cursor
                        try:
                            if not self.__r_check_vowel_harmony():
                                raise lab2()
                            if self.find_among_b(TurkishStemmer.a_9) == 0:
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_27
                        if not self.__r_check_vowel_harmony():
                            raise lab1()
                        if self.find_among_b(TurkishStemmer.a_2) == 0:
                            raise lab1()
                        break
                    while True:
                        v_28 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_sU():
                                raise lab2()
                            self.bra = self.cursor
                            self.slice_del()
                            v_29 = self.limit - self.cursor
                            try:
                                self.ket = self.cursor
                                if not self.__r_mark_lAr():
                                    self.cursor = self.limit - v_29
                                    raise lab3()
                                self.bra = self.cursor
                                self.slice_del()
                                if not self.__r_stem_suffix_chain_before_ki():
                                    self.cursor = self.limit - v_29
                                    raise lab3()
                            except lab3: pass
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_28
                        if not self.__r_mark_lArI():
                            raise lab1()
                        break
                    break
                except lab1: pass
                self.cursor = self.limit - v_18
                try:
                    self.ket = self.cursor
                    if not self.__r_check_vowel_harmony():
                        raise lab1()
                    if self.find_among_b(TurkishStemmer.a_8) == 0:
                        raise lab1()
                    self.bra = self.cursor
                    self.slice_del()
                    v_30 = self.limit - self.cursor
                    try:
                        self.ket = self.cursor
                        while True:
                            v_31 = self.limit - self.cursor
                            try:
                                if not self.__r_mark_possessives():
                                    raise lab3()
                                self.bra = self.cursor
                                self.slice_del()
                                v_32 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    if not self.__r_mark_lAr():
                                        self.cursor = self.limit - v_32
                                        raise lab4()
                                    self.bra = self.cursor
                                    self.slice_del()
                                    if not self.__r_stem_suffix_chain_before_ki():
                                        self.cursor = self.limit - v_32
                                        raise lab4()
                                except lab4: pass
                                break
                            except lab3: pass
                            self.cursor = self.limit - v_31
                            try:
                                if not self.__r_mark_lAr():
                                    raise lab3()
                                self.bra = self.cursor
                                self.slice_del()
                                v_33 = self.limit - self.cursor
                                try:
                                    if not self.__r_stem_suffix_chain_before_ki():
                                        self.cursor = self.limit - v_33
                                        raise lab4()
                                except lab4: pass
                                break
                            except lab3: pass
                            self.cursor = self.limit - v_31
                            if not self.__r_stem_suffix_chain_before_ki():
                                self.cursor = self.limit - v_30
                                raise lab2()
                            break
                    except lab2: pass
                    break
                except lab1: pass
                self.cursor = self.limit - v_18
                try:
                    self.ket = self.cursor
                    while True:
                        v_34 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_nUn():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_34
                        if not self.__r_check_vowel_harmony():
                            raise lab1()
                        if self.find_among_b(TurkishStemmer.a_10) == 0:
                            raise lab1()
                        if not self.__r_mark_suffix_with_optional_y_consonant():
                            raise lab1()
                        break
                    self.bra = self.cursor
                    self.slice_del()
                    v_35 = self.limit - self.cursor
                    try:
                        while True:
                            v_36 = self.limit - self.cursor
                            try:
                                self.ket = self.cursor
                                if not self.__r_mark_lAr():
                                    raise lab3()
                                self.bra = self.cursor
                                self.slice_del()
                                if not self.__r_stem_suffix_chain_before_ki():
                                    raise lab3()
                                break
                            except lab3: pass
                            self.cursor = self.limit - v_36
                            try:
                                self.ket = self.cursor
                                while True:
                                    v_37 = self.limit - self.cursor
                                    try:
                                        if not self.__r_mark_possessives():
                                            raise lab4()
                                        break
                                    except lab4: pass
                                    self.cursor = self.limit - v_37
                                    if not self.__r_mark_sU():
                                        raise lab3()
                                    break
                                self.bra = self.cursor
                                self.slice_del()
                                v_38 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    if not self.__r_mark_lAr():
                                        self.cursor = self.limit - v_38
                                        raise lab4()
                                    self.bra = self.cursor
                                    self.slice_del()
                                    if not self.__r_stem_suffix_chain_before_ki():
                                        self.cursor = self.limit - v_38
                                        raise lab4()
                                except lab4: pass
                                break
                            except lab3: pass
                            self.cursor = self.limit - v_36
                            if not self.__r_stem_suffix_chain_before_ki():
                                self.cursor = self.limit - v_35
                                raise lab2()
                            break
                    except lab2: pass
                    break
                except lab1: pass
                self.cursor = self.limit - v_18
                try:
                    self.ket = self.cursor
                    if not self.__r_mark_lArI():
                        raise lab1()
                    self.bra = self.cursor
                    self.slice_del()
                    break
                except lab1: pass
                self.cursor = self.limit - v_18
                try:
                    if not self.__r_stem_suffix_chain_before_ki():
                        raise lab1()
                    break
                except lab1: pass
                self.cursor = self.limit - v_18
                try:
                    self.ket = self.cursor
                    while True:
                        v_39 = self.limit - self.cursor
                        try:
                            if not self.__r_mark_DA():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_39
                        try:
                            if not self.__r_check_vowel_harmony():
                                raise lab2()
                            if not self.in_grouping_b(TurkishStemmer.g_U):
                                raise lab2()
                            if not self.__r_mark_suffix_with_optional_y_consonant():
                                raise lab2()
                            break
                        except lab2: pass
                        self.cursor = self.limit - v_39
                        if not self.__r_check_vowel_harmony():
                            raise lab1()
                        if self.find_among_b(TurkishStemmer.a_4) == 0:
                            raise lab1()
                        if not self.__r_mark_suffix_with_optional_y_consonant():
                            raise lab1()
                        break
                    self.bra = self.cursor
                    self.slice_del()
                    v_40 = self.limit - self.cursor
                    try:
                        self.ket = self.cursor
                        while True:
                            v_41 = self.limit - self.cursor
                            try:
                                if not self.__r_mark_possessives():
                                    raise lab3()
                                self.bra = self.cursor
                                self.slice_del()
                                v_42 = self.limit - self.cursor
                                try:
                                    self.ket = self.cursor
                                    if not self.__r_mark_lAr():
                                        self.cursor = self.limit - v_42
                                        raise lab4()
                                except lab4: pass
                                break
                            except lab3: pass
                            self.cursor = self.limit - v_41
                            if not self.__r_mark_lAr():
                                self.cursor = self.limit - v_40
                                raise lab2()
                            break
                        self.bra = self.cursor
                        self.slice_del()
                        self.ket = self.cursor
                        if not self.__r_stem_suffix_chain_before_ki():
                            self.cursor = self.limit - v_40
                            raise lab2()
                    except lab2: pass
                    break
                except lab1: pass
                self.cursor = self.limit - v_18
                self.ket = self.cursor
                while True:
                    v_43 = self.limit - self.cursor
                    try:
                        if not self.__r_mark_possessives():
                            raise lab1()
                        break
                    except lab1: pass
                    self.cursor = self.limit - v_43
                    if not self.__r_mark_sU():
                        raise lab0()
                    break
                self.bra = self.cursor
                self.slice_del()
                v_44 = self.limit - self.cursor
                try:
                    self.ket = self.cursor
                    if not self.__r_mark_lAr():
                        self.cursor = self.limit - v_44
                        raise lab1()
                    self.bra = self.cursor
                    self.slice_del()
                    if not self.__r_stem_suffix_chain_before_ki():
                        self.cursor = self.limit - v_44
                        raise lab1()
                except lab1: pass
                break
        except lab0: pass
        self.cursor = self.limit - v_17
        self.cursor = self.limit_backward
        self.limit_backward = self.cursor
        self.cursor = self.limit
        v_45 = self.limit - self.cursor
        try:
            if not self.eq_s_b("ad"):
                raise lab0()
            v_46 = self.limit - self.cursor
            try:
                if not self.eq_s_b("soy"):
                    self.cursor = self.limit - v_46
                    raise lab1()
            except lab1: pass
            if self.cursor > self.limit_backward:
                raise lab0()
            return False
        except lab0: pass
        self.cursor = self.limit - v_45
        v_47 = self.limit - self.cursor
        try:
            self.ket = self.cursor
            self.bra = self.cursor
            while True:
                try:
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "d":
                        raise lab1()
                    self.cursor -= 1
                    break
                except lab1: pass
                if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "g":
                    raise lab0()
                self.cursor -= 1
                break
            if not self.go_out_grouping_b(TurkishStemmer.g_vowel):
                raise lab0()
            while True:
                v_48 = self.limit - self.cursor
                try:
                    while True:
                        try:
                            if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "a":
                                raise lab2()
                            self.cursor -= 1
                            break
                        except lab2: pass
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "ı":
                            raise lab1()
                        self.cursor -= 1
                        break
                    self.slice_from("ı")
                    break
                except lab1: pass
                self.cursor = self.limit - v_48
                try:
                    while True:
                        try:
                            if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "e":
                                raise lab2()
                            self.cursor -= 1
                            break
                        except lab2: pass
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "i":
                            raise lab1()
                        self.cursor -= 1
                        break
                    self.slice_from("i")
                    break
                except lab1: pass
                self.cursor = self.limit - v_48
                try:
                    while True:
                        try:
                            if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "o":
                                raise lab2()
                            self.cursor -= 1
                            break
                        except lab2: pass
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "u":
                            raise lab1()
                        self.cursor -= 1
                        break
                    self.slice_from("u")
                    break
                except lab1: pass
                self.cursor = self.limit - v_48
                while True:
                    try:
                        if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "ö":
                            raise lab1()
                        self.cursor -= 1
                        break
                    except lab1: pass
                    if self.cursor <= self.limit_backward or self.current[self.cursor - 1] != "ü":
                        raise lab0()
                    self.cursor -= 1
                    break
                self.slice_from("ü")
                break
        except lab0: pass
        self.cursor = self.limit - v_47
        v_49 = self.limit - self.cursor
        try:
            self.ket = self.cursor
            among_var = self.find_among_b(TurkishStemmer.a_23)
            if among_var == 0:
                raise lab0()
            self.bra = self.cursor
            self.slice_from(TurkishStemmer.as_23[among_var - 1])
        except lab0: pass
        self.cursor = self.limit - v_49
        self.cursor = self.limit_backward
        return True

    a_0 = [
        Among("m", -1, -1),
        Among("n", -1, -1),
        Among("miz", -1, -1),
        Among("niz", -1, -1),
        Among("muz", -1, -1),
        Among("nuz", -1, -1),
        Among("müz", -1, -1),
        Among("nüz", -1, -1),
        Among("mız", -1, -1),
        Among("nız", -1, -1)
    ]

    a_1 = [
        Among("leri", -1, -1),
        Among("ları", -1, -1)
    ]

    a_2 = [
        Among("ni", -1, -1),
        Among("nu", -1, -1),
        Among("nü", -1, -1),
        Among("nı", -1, -1)
    ]

    a_3 = [
        Among("in", -1, -1),
        Among("un", -1, -1),
        Among("ün", -1, -1),
        Among("ın", -1, -1)
    ]

    a_4 = [
        Among("a", -1, -1),
        Among("e", -1, -1)
    ]

    a_5 = [
        Among("na", -1, -1),
        Among("ne", -1, -1)
    ]

    a_6 = [
        Among("da", -1, -1),
        Among("ta", -1, -1),
        Among("de", -1, -1),
        Among("te", -1, -1)
    ]

    a_7 = [
        Among("nda", -1, -1),
        Among("nde", -1, -1)
    ]

    a_8 = [
        Among("dan", -1, -1),
        Among("tan", -1, -1),
        Among("den", -1, -1),
        Among("ten", -1, -1)
    ]

    a_9 = [
        Among("ndan", -1, -1),
        Among("nden", -1, -1)
    ]

    a_10 = [
        Among("la", -1, -1),
        Among("le", -1, -1)
    ]

    a_11 = [
        Among("ca", -1, -1),
        Among("ce", -1, -1)
    ]

    a_12 = [
        Among("im", -1, -1),
        Among("um", -1, -1),
        Among("üm", -1, -1),
        Among("ım", -1, -1)
    ]

    a_13 = [
        Among("sin", -1, -1),
        Among("sun", -1, -1),
        Among("sün", -1, -1),
        Among("sın", -1, -1)
    ]

    a_14 = [
        Among("iz", -1, -1),
        Among("uz", -1, -1),
        Among("üz", -1, -1),
        Among("ız", -1, -1)
    ]

    a_15 = [
        Among("siniz", -1, -1),
        Among("sunuz", -1, -1),
        Among("sünüz", -1, -1),
        Among("sınız", -1, -1)
    ]

    a_16 = [
        Among("lar", -1, -1),
        Among("ler", -1, -1)
    ]

    a_17 = [
        Among("niz", -1, -1),
        Among("nuz", -1, -1),
        Among("nüz", -1, -1),
        Among("nız", -1, -1)
    ]

    a_18 = [
        Among("dir", -1, -1),
        Among("tir", -1, -1),
        Among("dur", -1, -1),
        Among("tur", -1, -1),
        Among("dür", -1, -1),
        Among("tür", -1, -1),
        Among("dır", -1, -1),
        Among("tır", -1, -1)
    ]

    a_19 = [
        Among("casına", -1, -1),
        Among("cesine", -1, -1)
    ]

    a_20 = [
        Among("di", -1, -1),
        Among("ti", -1, -1),
        Among("dik", -1, -1),
        Among("tik", -1, -1),
        Among("duk", -1, -1),
        Among("tuk", -1, -1),
        Among("dük", -1, -1),
        Among("tük", -1, -1),
        Among("dık", -1, -1),
        Among("tık", -1, -1),
        Among("dim", -1, -1),
        Among("tim", -1, -1),
        Among("dum", -1, -1),
        Among("tum", -1, -1),
        Among("düm", -1, -1),
        Among("tüm", -1, -1),
        Among("dım", -1, -1),
        Among("tım", -1, -1),
        Among("din", -1, -1),
        Among("tin", -1, -1),
        Among("dun", -1, -1),
        Among("tun", -1, -1),
        Among("dün", -1, -1),
        Among("tün", -1, -1),
        Among("dın", -1, -1),
        Among("tın", -1, -1),
        Among("du", -1, -1),
        Among("tu", -1, -1),
        Among("dü", -1, -1),
        Among("tü", -1, -1),
        Among("dı", -1, -1),
        Among("tı", -1, -1)
    ]

    a_21 = [
        Among("sa", -1, -1),
        Among("se", -1, -1),
        Among("sak", -1, -1),
        Among("sek", -1, -1),
        Among("sam", -1, -1),
        Among("sem", -1, -1),
        Among("san", -1, -1),
        Among("sen", -1, -1)
    ]

    a_22 = [
        Among("miş", -1, -1),
        Among("muş", -1, -1),
        Among("müş", -1, -1),
        Among("mış", -1, -1)
    ]

    a_23 = [
        Among("b", -1, 1),
        Among("c", -1, 2),
        Among("d", -1, 3),
        Among("ğ", -1, 4)
    ]
    as_23 = ("p", "ç", "t", "k")


class lab0(BaseException): pass


class lab1(BaseException): pass


class lab2(BaseException): pass


class lab3(BaseException): pass


class lab4(BaseException): pass
