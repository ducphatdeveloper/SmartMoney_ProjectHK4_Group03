package fpt.aptech.server.enums.category;

import lombok.Getter;

@Getter
public enum CategoryType {
    EXPENSE(0), // Chi tiêu
    INCOME(1);  // Thu nhập

    private final int value;

    CategoryType(int value) {
        this.value = value;
    }
}