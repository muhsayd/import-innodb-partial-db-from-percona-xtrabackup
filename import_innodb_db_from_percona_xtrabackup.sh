#! /bin/bash -X

database=${1}
mysqlbasedir='/var/lib/mysql/'
dbBkPath="/backup/cpbackup/${database}"
argsNum=4
tables=''

get_DB_Tables ()
  {
        mysqlshow ${database} | sed '1,/Tables/d' | awk '{print $2}' | sed '/^$/d'
  }
drop_Table ()
  {
        db=${1}
        tablename=${2}
        mysql -e "drop table ${db}.${tablename};" >/dev/null
  }

createTableDumpFile=''
isolate_Table_Structure ()
  {
        table=${1}
        createDumpFile=${2}
        backupdir=${3}
        createTableDumpFile="${backupdir}/${table}.create"
        perl /root/extract_table_from_mysqldump.pl ${table} < ${createDumpFile} > ${createTableDumpFile}
  }

create_Table ()
  {
        table=${1}
        backupdir=${2}
        createDumpFile=${3}
        db=${4}
        isolate_Table_Structure ${table} ${createDumpFile} ${backupdir}
#       createTableDumpFile=$(isolate_Table_Structure ${table} ${createDumpFile} ${backupdir})
        echo -e "\t\t\tCreate Table Structure"
#       cat ${createTableDumpFile}
        mysql ${db} < ${createTableDumpFile}
  }
create_Tables ()
  {
        db=${1}
        createfile=${2}
        mysql ${db} < ${createfile}
  }
alter_Table_TO_InnoDB_Engine ()
  {
        db=${1}
        tablename=${2}
        mysql -e "alter table ${db}.${tablename} ENGINE=InnoDB;"
  }
discard_TableSpace ()
  {
        db=${1}
        tablename=${2}
        mysql -e "alter table ${db}.${tablename} DISCARD TABLESPACE;"
  }
copy_Table_IDB_File ()
  {
        backupPath=${1}
        db=${2}
        tablename=${3}
        mysqlbasedir=${4}
        (cp -pvf        ${backupPath}/${tablename}.ibd ${mysqlbasedir}/${db}/${tablename}.ibd) && (echo "table ${tablename}.ibd coppied") || (echo "error copping ${tablename}.ibd" > /dev/null)
        chown mysql:mysql ${mysqlbasedir}/${db}/${tablename}.ibd
        chmod ug+rw ${mysqlbasedir}/${db}/${tablename}.ibd
        chmod o+r ${mysqlbasedir}/${db}/${tablename}.ibd
  }
copy_Table_CFG_file ()
  {
        backupPath=${1}
        db=${2}
        tablename=${3}
        mysqlbasedir=${4}

        (cp -pvf        ${backupPath}/${tablename}.cfg ${mysqlbasedir}/${db}/${tablename}.cfg) && (echo "table ${tablename}.cfg coppied ") || (echo "error
copping ${tablename}.cfg")
        chown mysql:mysql ${mysqlbasedir}/${db}/${tablename}.cfg
        chmod ug+rw ${mysqlbasedir}/${db}/${tablename}.cfg
        chmod o+r ${mysqlbasedir}/${db}/${tablename}.cfg
  }
force_Table () {
        db=${1}
        tablename=${2}
        mysql -e "alter table ${db}.${tablename} force;"
}
import_TableSpace ()
  {
        db=${1}
        tablename=${2}
        mysql -e "alter table ${db}.${tablename} IMPORT TABLESPACE;"

  }
usage ()
  {
        echo -e "You must path ${argsNum} Args to the script\nUsage:\n$0 database databasebackuppath mysqlbasedir createdumpfile"
  }
check_Args ()
  {
        echo "number of args is: ${#@} they are ${@}"
        if [ ${#@} -lt ${argsNum} ]
        then
                usage
                exit 5
        fi
  }
remove_cfg(){
db=${1}
table=${2}
mysqlbasedir='/var/lib/mysql'
filetodelete="${mysqlbasedir}/${db}/${table}.cfg"
echo "file to delete ${db} ${table} ${filetodelete}"
rm -f ${filetodelete} && echo "${filetodelete} Deleted"
}
check_ExitStatus (){
        exitstatus=${1}
        db=${2}
        table=${3}
        message=${4}
        echo -e "\t\texit status ${exitstatus}"
        echo -e "\t\t db: ${db}"
        echo -e "\t\t ${table}"
        echo -e "\t\t ${message}"
        if [ "${exitstatus}" -ne 0 ]
        then
                echo ${message}
                remove_cfg ${db} ${table}
                ((import_TableSpace ${db} ${table}) && (echo "Table: ${table} Storage Engine imported Again"))
#                        check_ExitStatus ${?} ${table} "error importing the tablespace for table ${table}"
                if [ "${?}" -ne 0 ]
                then
                        echo -e "${table}:failed to be Restored" >> /root/failed_To_Rrestore_Tables.txt
                        exit "$?"
#               echo -e "${table}:failed to be Restored" >> /root/failed_To_Rrestore_Tables.txt
                fi
        else
                echo -e "${table}:Restored Successfully" >> /root/success_To_Rrestore_Tables.txt
        fi
}
do_The_Backup ()
  {
        db=${1}
        bkpath=${2}
        mysqlbasedir=${3}
        createDumpFile=${4}

        tablelist=$(get_DB_Tables ${db})
        check_Args ${@}
        chmod 700 ${mysqlbasedir}/${db}

#        if [ ${tablelist} = '' ]
#        then
#                echo " the databse is empty, you need to create the database tables;"
#                create_Tables ${database} ${createDumpFile}
##               exit 10
#        fi
        rm -f /root/{failed_To_Rrestore_Tables,success_To_Rrestore_Tables}.txt
        if [ "$verpose" -eq 1 ]
        then
                for table in $tablelist
                do
                        agrament=$(adminAgreement "Do you want to drop table ${table}")
                        if [ "$agrament" -eq 1 ]
                        then
                                ((drop_Table ${db} ${table}) && (echo "Table: ${table} Dropped"))
#                               check_ExitStatus ${?} ${table} "error Dropping Table ${table}"
                        fi
                        agrament=$(adminAgreement "Do you want to drop table ${table}")
                        if [ "$agrament" -eq 1 ]
                        then
                                ((create_Table ${table} ${bkpath} ${createDumpFile} ${database}) && (echo "Table: ${table} Created"))
#                               check_ExitStatus ${?} ${table} "error Creating Table ${table}"
                        fi
#                      create_Table ${db} ${table} && echo "Table: ${table} Created"
                        agrament=$(adminAgreement "Do you want to drop table ${table}")
                        if [ "$agrament" -eq 1 ]
                        then
                                ((alter_Table_TO_InnoDB_Engine ${db} ${table}) && (echo "Table: ${table} Storage Engine Changed to innoDB"))
#                               check_ExitStatus ${?} ${table} "error changing storage engine for table ${table}"
                        fi
                        agrament=$(adminAgreement "Do you want to drop table ${table}")
                        if [ "$agrament" -eq 1 ]
                        then
                                ((force_Table ${db} ${table}) && (echo "Table: ${table} Altered to force TempOral"))
#                                check_ExitStatus ${?} ${table} "Error Forcing TempOral for table ${table}"
                        fi
                        agrament=$(adminAgreement "Do you want to drop table ${table}")
                        if [ "$agrament" -eq 1 ]
                        then
                                ((discard_TableSpace ${db} ${table}) && (echo "Table: ${table} Storage Engine Discarded"))
#                               check_ExitStatus ${?} ${table} "error discarding the tablespace for table ${table}"
                        fi
                        agrament=$(adminAgreement "Do you want to drop table ${table}")
                        if [ "$agrament" -eq 1 ]
                        then
                               ((copy_Table_IDB_File ${bkpath} ${db} ${table} ${mysqlbasedir}) && (echo "Table: ${table} .ibd file coppied"))
#                               check_ExitStatus ${?} ${table} "error copping .ibd file for table ${table}"
                        fi
                        agrament=$(adminAgreement "Do you want to drop table ${table}")
                        if [ "$agrament" -eq 1 ]
                        then
#                        ((copy_Table_CFG_file ${bkpath} ${db} ${table} ${mysqlbasedir}) && (echo "Table: ${table} .cfg file coppied"))
#                               check_ExitStatus ${?} ${table} "error copping .cfg file for table ${table}"
                        fi
                        agrament=$(adminAgreement "Do you want to drop table ${table}")
                        if [ "$agrament" -eq 1 ]
                        then
                                ((import_TableSpace ${db} ${table}) && (echo "Table: ${table} Storage Engine imported Again"))
                                check_ExitStatus ${?} ${db} ${table} "error importing the tablespace for table ${table}"
                        fi
                done
        else
        for table in $tablelist
        do

                ((drop_Table ${db} ${table}) && (echo "Table: ${table} Dropped"))
#                       check_ExitStatus ${?} ${table} "error Dropping Table ${table}"
                ((create_Table ${table} ${bkpath} ${createDumpFile} ${database}) && (echo "Table: ${table} Created"))
#                       check_ExitStatus ${?} ${table} "error Creating Table ${table}"
#               create_Table ${db} ${table} && echo "Table: ${table} Created"
                ((alter_Table_TO_InnoDB_Engine ${db} ${table}) && (echo "Table: ${table} Storage Engine Changed to innoDB"))
#                       check_ExitStatus ${?} ${table} "error changing storage engine for table ${table}"
                ((force_Table ${db} ${table}) && (echo "Table: ${table} Altered to force TempOral"))
#                        check_ExitStatus ${?} ${table} "Error Forcing TempOral for table ${table}"
                ((discard_TableSpace ${db} ${table}) && (echo "Table: ${table} Storage Engine Discarded"))
#                       check_ExitStatus ${?} ${table} "error discarding the tablespace for table ${table}"
               ((copy_Table_IDB_File ${bkpath} ${db} ${table} ${mysqlbasedir}) && (echo "Table: ${table} .ibd file coppied"))
#                       check_ExitStatus ${?} ${table} "error copping .ibd file for table ${table}"
#                ((copy_Table_CFG_file ${bkpath} ${db} ${table} ${mysqlbasedir}) && (echo "Table: ${table} .cfg file coppied"))
#                       check_ExitStatus ${?} ${table} "error copping .cfg file for table ${table}"
                ((import_TableSpace ${db} ${table}) && (echo "Table: ${table} Storage Engine imported Again"))
                        check_ExitStatus ${?} ${db} ${table} "error importing the tablespace for table ${table}"
        done
        fi
  }

do_The_Backup ${@} #${database} ${dbBkPath} ${mysqlbasedir} ${createDumpFile}
