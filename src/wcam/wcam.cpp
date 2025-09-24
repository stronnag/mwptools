//  g++ -o wcam.exe wcam.cpp -lole32 -loleaut32 -lstrmiids


#include <windows.h>
#include <dshow.h>
#include <cstring>
#include <string.h>
#include <locale.h>

HRESULT EnumerateDevices(REFGUID category, IEnumMoniker **ppEnum) {
    HRESULT hr;
    ICreateDevEnum *pDevEnum = NULL;
    hr = CoCreateInstance(CLSID_SystemDeviceEnum, NULL, CLSCTX_INPROC_SERVER,
                          IID_ICreateDevEnum, (void **)&pDevEnum);

    if (SUCCEEDED(hr)) {
        hr = pDevEnum->CreateClassEnumerator(category, ppEnum, 0);
        if (hr == S_FALSE) {
            hr = VFW_E_NOT_FOUND; // The category is empty. Treat as an error.
        }
        pDevEnum->Release();
    }
    return hr;
}

char *to_utf8( wchar_t* wchars) {
  int nl = wcslen(wchars);
  int len = WideCharToMultiByte(CP_UTF8, 0, wchars, nl, 0, 0, NULL, NULL);
  char *lname = (char*)malloc(len+1);
  WideCharToMultiByte(CP_UTF8, 0, wchars, nl, lname, len, NULL, NULL);
  lname[len] = '\0';
  return lname;
}

void DisplayDeviceInformation(IEnumMoniker *pEnum, char *buf) {
  char *rval = buf;

  IMoniker *pMoniker = NULL;

  while (pEnum->Next(1, &pMoniker, NULL) == S_OK) {
    IPropertyBag *pPropBag;
    HRESULT hr = pMoniker->BindToStorage(0, 0, IID_PPV_ARGS(&pPropBag));
    if (FAILED(hr)) {
      pMoniker->Release();
      continue;
    }

    VARIANT var;
    VariantInit(&var);

    // Get description or friendly name.
    hr = pPropBag->Read(L"Description", &var, 0);
    if (FAILED(hr)) {
      hr = pPropBag->Read(L"FriendlyName", &var, 0);
    }
    if (SUCCEEDED(hr)) {
      char* lname = to_utf8(var.bstrVal);
      strcpy(rval, lname);
      rval += strlen(lname);
      *rval++ = '\t';
      free(lname);
      VariantClear(&var);
    }

    hr = pPropBag->Read(L"DevicePath", &var, 0);
    if (SUCCEEDED(hr)) {
      char* lname = to_utf8(var.bstrVal);
      strcpy(rval, lname);
      rval += strlen(lname);
      *rval++ = '\r';
      free(lname);
      VariantClear(&var);
    }
    pPropBag->Release();
    pMoniker->Release();
  }
  if(strlen(buf) > 0) {
    *--rval= 0;
  }
}

extern "C" char *get_cameras();

char * get_cameras() {
    HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    char *cbuf = NULL;

    if (SUCCEEDED(hr)) {
        IEnumMoniker *pEnum;
	hr = EnumerateDevices(CLSID_VideoInputDeviceCategory, &pEnum);
        if (SUCCEEDED(hr)) {
	  cbuf = (char *)calloc(sizeof(char), 32*1024);
	  DisplayDeviceInformation(pEnum, cbuf);
	  pEnum->Release();
        }
        CoUninitialize();
    }
    return cbuf;
}
