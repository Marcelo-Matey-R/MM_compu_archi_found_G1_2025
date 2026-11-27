int datos[10];

void fill(int arr[]) {
    for (int i = 0; i < 10; i++)
        arr[i] = i;
}

int sumas(int arr[]) {
    int suma = 0;
    for (int i = 0; i < 10; i++)
        suma += arr[i];
    return suma;
}

int main() {
    fill(datos);
    return sumas(datos);    // debe dar 45
}
