#!/home/a127769_tr1/homepython/bin/mypy/bin/python
import pandas as pd
import sys
import warnings

def search_excel_file(file_path, search_string):
    # Disable warnings from openpyxl
    warnings.filterwarnings("ignore", category=UserWarning, module="openpyxl")
    #Read the Excel file into a pandas DataFrame
    df = pd.read_excel(file_path)

    #Check if the required columns exist in the DataFrame
    if 'vm_name' not in df.columns or  'vcenter_name' not in df.columns:
        print("Error: Excel file has no DC info")
        return
    #Filter the DataFrame based on the search criteria
    filtered_df = df[df['vm_name'].str.strip().str.contains(search_string, case=False, na=False)]

    #Check if any matching rows were found
    if filtered_df.empty:
        print("No matching record found.")
    else:
        for index, row in filtered_df.iterrows():
            print(f"vcenter_name: {row['vcenter_name']} | vm_name: {row['vm_name']}")

if __name__ == '__main__':
#    if len(sys.argv) < 3:
#        print("Usage: python search_excel.py <file_path> <search_string>")
#        sys.exit(1)
    if len(sys.argv) < 2:
        print("Usage: finddc.py <search_string>")
        sys.exit(1)

    #file_path = sys.argv[1]
    file_path = "./vminventory.xlsx"
    #search_string = sys.argv[2]
    search_string = sys.argv[1]
    search_excel_file(file_path, search_string)
